#!/bin/bash

# Set the repository URL and target directory
repo_url="https://github.com/ns144/Transcription-Application.git"
target_dir="/home/ubuntu/Transcription-Application"
log_file="/var/log/Transcription-Application.log"

exec > >(tee -a "$log_file") 2>&1

# Check if the target directory exists and is a Git repository
if [ -d "$target_dir/.git" ]; then
# If it's a Git repository, pull the latest changes
cd "$target_dir"
git pull origin main
echo "Repository pulled."
else
# If it's not a Git repository, clone the repository
git clone "$repo_url" "$target_dir"

# Navigate to the repository directory
cd "$target_dir"
fi

# Install requirements
sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install -y python3-pip
sudo apt install -y ffmpeg
sudo apt-get install amazon-cloudwatch-agent -y

pip install openai-whisper --no-cache-dir
#pip install faster-whisper
pip install git+https://github.com/jiaaro/pydub.git@master
pip install pyannote.audio

#pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Install WhisperV3
pip install --upgrade transformers datasets[audio] accelerate

pip install -r requirements.txt

# Create Amazon CloudWatch Agent config file
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/
sudo tee /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent.json > /dev/null <<EOL
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/Python-Transcription-Application.log",
                        "log_group_name": "transcription-server_ec2",
                        "log_stream_name": "{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    },
                    {
                        "file_path": "/var/log/Transcription-Application.log",
                        "log_group_name": "ec2-init",
                        "log_stream_name": "{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    },
                    {
                        "file_path": "/var/log/startup.log",
                        "log_group_name": "ec2-startup",
                        "log_stream_name": "{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    }
                ]
            }
        }
    },
    "metrics": {
        "aggregation_dimensions" : [["AutoScalingGroupName"],[]],
        "metrics_collected": {
            "nvidia_gpu": {
                "measurement": [
                    "utilization_gpu",
                    "utilization_memory",
                    "memory_total",
                    "memory_used",
                    "memory_free",
                    "clocks_current_graphics",
                    "clocks_current_sm",
                    "clocks_current_memory"
                ],
                "metrics_collection_interval": 10
            }
        }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "ton-texter-transcription-servers"
    }
}
EOL


# Start Amazon CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent.json \
    -s

# Configure Startup Script
sudo cat >/home/ubuntu/startup.sh <<EOL
#!/bin/bash

log_file="/var/log/startup.log"
target_dir="/home/ubuntu/Transcription-Application"

exec > >(tee -a "\$log_file") 2>&1

cd "\$target_dir"
sudo git pull
sudo python3 main.py

EOL
sudo cat /home/ubuntu/startup.sh

# Enable Startup Script
sudo chmod +x /home/ubuntu/startup.sh

# Autostart
sudo cat >/etc/cron.d/startup_script <<EOL
@reboot root /home/ubuntu/startup.sh
EOL
sudo cat /etc/cron.d/startup_script
sudo poweroff
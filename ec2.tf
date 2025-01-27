# IAM Role for EC2 instance
resource "aws_iam_role" "access_s3_and_logs" {
  name = "access_s3_and_logs_role"
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AmazonS3FullAccess policy to the role
resource "aws_iam_role_policy_attachment" "s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.access_s3_and_logs.name
}

# Additional policy for accessing Secrets Manager
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "secrets_manager_policy"
  description = "Policy for accessing AWS Secrets Manager"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
  role       = aws_iam_role.access_s3_and_logs.name
}

# Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "cloudwatch_logs_policy"
  description = "Policy for EC2 to write logs and metrics to CloudWatch"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:CreateLogDelivery",
        "logs:UpdateLogDelivery"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricStream",
        "cloudwatch:PutMetricData",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "cloudwatch_logs_access" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
  role       = aws_iam_role.access_s3_and_logs.name
}

# IAM Instance Profile for the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_and_logs_profile"
  role = aws_iam_role.access_s3_and_logs.name
}

resource "aws_instance" "transcription_server" {
# AMI Ubuntu Server 22.04 LTS X86 
#  ami           = "ami-06dd92ecc74fdfb36"
  # Nividia AMI
  #ami = "ami-0d5a2db5629a8fbcc"
  
  #Ubuntu Pytorch AMI
  ami = "ami-0fa5e5fd27b3e163a"
  # Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 20.04)
  #ami = "ami-0c650d5ec9c783d4b"
  #ami = "ami-0e33bf2e5ba14b3fb"
  instance_type = "g4dn.xlarge"

  # Assign a public IP address
  associate_public_ip_address = true

  # Should make shure that ec2 is not running initially
  user_data = "${file("init_transcript.sh")}"  
  user_data_replace_on_change = true

  tags = {

    Name = "Transcription Server For AMI"

  }
  # Security Group allowing traffic from everywhere (0.0.0.0/0)
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  key_name = "ssh_access"

  # IAM Instance Profile for CloudWatch Logs and S3
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  #root_block_device {
  #  volume_size = 128  # New root volume size in GB
  #}
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound and outbound traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#resource "aws_key_pair" "ssh_access" {
#  key_name   = "ssh-key"
#  public_key = tls_private_key.rsa_4096_key.public_key_openssh
#}
#
## RSA key of size 4096 bits
#resource "tls_private_key" "rsa_4096_key" {
#  algorithm = "RSA"
#  rsa_bits  = 4096
#}

#resource "aws_ec2_instance_state" "state_stopped" {
#  instance_id = aws_instance.transcription_server.id
#  state       = "stopped"
#}
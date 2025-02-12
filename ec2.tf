# IAM Role for EC2 instance
resource "aws_iam_role" "access_s3_and_logs_ami" {
  name = "access_s3_and_logs_ami_role"
  
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
resource "aws_iam_role_policy_attachment" "s3_access_ami" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.access_s3_and_logs_ami.name
}

# Additional policy for accessing Secrets Manager
resource "aws_iam_policy" "secrets_manager_policy_ami" {
  name        = "secrets_manager_policy_ami"
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

resource "aws_iam_role_policy_attachment" "secrets_manager_access_ami" {
  policy_arn = aws_iam_policy.secrets_manager_policy_ami.arn
  role       = aws_iam_role.access_s3_and_logs_ami.name
}

# Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy_ami" {
  name        = "cloudwatch_logs_policy_ami"
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


resource "aws_iam_role_policy_attachment" "cloudwatch_logs_access_ami" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy_ami.arn
  role       = aws_iam_role.access_s3_and_logs_ami.name
}

resource "aws_iam_policy" "ec2_ami_policy" {
  name        = "EC2_AMI_launch_template_policy"
  description = "Allows EC2 to create AMIs and Launch Templates"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateImage",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:CreateLaunchTemplate",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetLaunchTemplateData"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_ami_policy" {
  policy_arn = aws_iam_policy.ec2_ami_policy.arn
  role       = aws_iam_role.access_s3_and_logs_ami.name
}


# IAM Instance Profile for the EC2 instance
resource "aws_iam_instance_profile" "ec2_profile_ami" {
  name = "ec2_s3_and_logs_profile_ami"
  role = aws_iam_role.access_s3_and_logs_ami.name
}

resource "aws_instance" "transcription_server_ami" {
  
  #Ubuntu Pytorch AMI
  ami = "ami-0fa5e5fd27b3e163a"
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
  vpc_security_group_ids = [aws_security_group.allow_all_ami.id]
  key_name = "ssh_access"

  # IAM Instance Profile for CloudWatch Logs and S3
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_ami.name

  root_block_device {
    volume_type = "gp3"          # Change to GP3 for higher performance
     volume_size = 50            # Adjust size as needed
     iops        = 16000          # Set IOPS to 16,000
     throughput  = 1000           # Set throughput to 1,000 MB/s
  }
}

resource "aws_security_group" "allow_all_ami" {
  name        = "allow_all_ami"
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
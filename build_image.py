import boto3
import time
import os
import json
import base64
ec2_client = boto3.client('ec2', region_name='eu-central-1')


def lambda_handler(event, context):

    try:
        params = event['queryStringParameters']
        INSTANCE_ID = params['ec2_id']
        key = params['key']
    except KeyError:
        response = "No InstanceId provided"
        return {'statusCode': 401, 'body': json.dumps(response)}

    secret = os.environ['SECRET']
    secret = base64.b64decode(secret)
    secret = json.loads(secret)
    transcription_key = secret['TRANSCRIPTION_SERVICE_API_KEY']

    if key != transcription_key:
        response = "Incorrect API Key provided"
        return {'statusCode': 401, 'body': json.dumps(response)}

    try:
        # Step 1: Create AMI
        ami_name = f"Transcription-Server-AMI-{int(time.time())}"
        ami_response = ec2_client.create_image(
            InstanceId=INSTANCE_ID,
            Name=ami_name,
            NoReboot=False
        )
        ami_id = ami_response['ImageId']
        print(f"AMI Creation Initiated: {ami_id}")

        # Step 2: Wait for AMI to become available
        waiter = ec2_client.get_waiter('image_available')
        waiter.wait(ImageIds=[ami_id])
        print(f"AMI is now available: {ami_id}")

        # Step 3: Create a Launch Template using the new AMI
        launch_template_name = "Transcription-Server-Template"
        template_response = ec2_client.create_launch_template(
            LaunchTemplateName=launch_template_name,
            LaunchTemplateData={
                'ImageId': ami_id,
                'InstanceType': 'g4dn.xlarge',
                'KeyName': 'ssh_access',
                'SecurityGroupIds': ['sg-0b37fa617eabd748d'],
                'BlockDeviceMappings': [
                    {
                        'DeviceName': '/dev/sda1',  # Root volume
                        'Ebs': {
                            'VolumeSize': 45,
                            'VolumeType': 'gp3',
                            'Iops': 16000,  # 16K IOPS
                            'Throughput': 1000,  # 1000 MB/s
                            'DeleteOnTermination': True
                        }
                    }
                ]
            }
        )

        template_id = template_response['LaunchTemplate']['LaunchTemplateId']
        print(f"Launch Template Created: {template_id}")

        return {
            "statusCode": 200,
            "body": f"Launch Template Created: {template_id} with AMI: {ami_id}"
        }

    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": f"Error: {str(e)}"
        }

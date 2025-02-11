variable "transcription_api_key" {
  description = "TRANSCRIPTION_SERVICE_API_KEY"
  type        = string
}


data "archive_file" "lambda_package" {

  type = "zip"

  source_file = "build_image.py"

  output_path = "build_image.zip"

}

# Create Lambda Function
resource "aws_lambda_function" "build_image_lambda" {

  filename = "build_image.zip"

  function_name = "buildAMIandLaunchTemplate"

  role = aws_iam_role.build_lambda_role.arn

  handler = "build_image_lambda.lambda_handler"

  runtime = "python3.10"

  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
        SECRET = var.transcription_api_key
    }
  }

  timeout = 600
}


resource "aws_iam_role" "build_lambda_role" {

  name = "lambda-role"



  assume_role_policy = jsonencode({

    Version = "2012-10-17",

    Statement = [

    {

      Action = "sts:AssumeRole",

      Effect = "Allow",

      Principal = {

        Service = "lambda.amazonaws.com"

      }

    }

  ]

})

}

resource "aws_iam_policy" "ec2_policy" {
  name        = "EC2LambdaPolicy"
  description = "Policy to allow Lambda to create AMI and launch template"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateImage",
        "ec2:DescribeImages",
        "ec2:CreateLaunchTemplate",
        "ec2:DescribeInstances",
        "ec2:GetLaunchTemplateData"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_ec2_policy" {
  role       = aws_iam_role.build_lambda_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# Attach AWS Lambda Basic Execution Role
resource "aws_iam_role_policy_attachment" "attach_basic_execution" {
  role       = aws_iam_role.build_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "LambdaAPI"
  protocol_type = "HTTP"
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.build_image_lambda.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /build-image"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "dev"
  auto_deploy = true
}

# Lambda Permission to be Invoked by API Gateway
resource "aws_lambda_permission" "apigw_lambda" {

  statement_id = "AllowExecutionFromAPIGateway"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.build_image_lambda.function_name

  principal = "apigateway.amazonaws.com"

}

# Output API Gateway Endpoint
output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/build-image"
}
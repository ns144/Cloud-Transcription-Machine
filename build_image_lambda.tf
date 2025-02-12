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

  handler = "build_image.lambda_handler"

  runtime = "python3.10"

  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
        SECRET = var.transcription_api_key
    }
  }

  timeout = 1200
}


resource "aws_iam_role" "build_lambda_role" {

  name = "build-lambda-role"



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
        "ec2:CreateLaunchTemplateVersion",
        "ec2:ModifyLaunchTemplate",
        "ec2:DescribeInstances",
        "ec2:StopInstances",
        "ec2:GetLaunchTemplateData",
        "ec2:TerminateInstances"
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
resource "aws_api_gateway_rest_api" "build_image_gateway" {

  name = "build_image-api"

  description = "API Endpoint for the creation of a Launch Template"



  endpoint_configuration {

    types = ["REGIONAL"]

  }

}
resource "aws_api_gateway_resource" "build_root" {

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id

  parent_id = aws_api_gateway_rest_api.build_image_gateway.root_resource_id

  path_part = "build_image"

}

resource "aws_api_gateway_method" "build_proxy" {

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id

  resource_id = aws_api_gateway_resource.build_root.id

  http_method = "GET"
  
  authorization = "NONE"

}

resource "aws_api_gateway_integration" "build_lambda_integration" {

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id

  resource_id = aws_api_gateway_resource.build_root.id

  http_method = aws_api_gateway_method.build_proxy.http_method

  integration_http_method = "POST"

  type = "AWS_PROXY"
  uri = aws_lambda_function.build_image_lambda.invoke_arn

}

resource "aws_api_gateway_method_response" "build_proxy" {

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id

  resource_id = aws_api_gateway_resource.build_root.id

  http_method = aws_api_gateway_method.build_proxy.http_method

  status_code = "200"

    //cors section

  response_parameters = {

    "method.response.header.Access-Control-Allow-Headers" = true,

    "method.response.header.Access-Control-Allow-Methods" = true,

    "method.response.header.Access-Control-Allow-Origin" = true

  }

}

resource "aws_api_gateway_integration_response" "build_proxy" {

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id

  resource_id = aws_api_gateway_resource.build_root.id

  http_method = aws_api_gateway_method.build_proxy.http_method

  status_code = aws_api_gateway_method_response.build_proxy.status_code

  //cors

  response_parameters = {

    "method.response.header.Access-Control-Allow-Headers" =  "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",

    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",

    "method.response.header.Access-Control-Allow-Origin" = "'*'"

  }

  depends_on = [

    aws_api_gateway_method.build_proxy,

    aws_api_gateway_integration.build_lambda_integration

  ]

}

resource "aws_api_gateway_deployment" "build_deployment" {
  depends_on = [
    aws_api_gateway_integration.build_lambda_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.build_image_gateway.id
}

resource "aws_api_gateway_stage" "build_dev" {
  deployment_id = aws_api_gateway_deployment.build_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.build_image_gateway.id
  stage_name    = "dev"
}


resource "aws_lambda_permission" "build_apigw_lambda" {

  statement_id = "AllowExecutionFromAPIGateway"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.build_image_lambda.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.build_image_gateway.execution_arn}/*/*/*"

}
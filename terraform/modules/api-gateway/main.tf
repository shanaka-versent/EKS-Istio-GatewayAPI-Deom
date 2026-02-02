# MTKC POC EKS - AWS API Gateway Foundations Module
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# Layer 2: Base EKS Cluster Setup - API Gateway Foundations
# Creates the foundational API Gateway resources:
# - VPC Link (connectivity to private VPC)
# - HTTP API (the API Gateway itself)
# - Default Stage
#
# App-specific routes and integrations are managed by ArgoCD via ACK CRDs

# Security Group for VPC Link
resource "aws_security_group" "vpc_link" {
  name        = "${var.name_prefix}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = var.vpc_id

  # Allow HTTPS outbound to VPC CIDR (for Internal NLB)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to Internal NLB"
  }

  # Allow HTTP outbound to VPC CIDR (for Internal NLB)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP to Internal NLB"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-link-sg"
  })
}

# VPC Link for private connectivity
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.name_prefix}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-link"
  })
}

# HTTP API (API Gateway v2)
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.name_prefix} - Routes managed by ArgoCD/ACK"

  cors_configuration {
    allow_origins     = var.cors_allow_origins
    allow_methods     = var.cors_allow_methods
    allow_headers     = var.cors_allow_headers
    expose_headers    = var.cors_expose_headers
    max_age           = var.cors_max_age
    allow_credentials = var.cors_allow_credentials
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api"
  })
}

# Default Stage with auto-deploy
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        routeKey       = "$context.routeKey"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
        errorMessage   = "$context.error.message"
      })
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-default-stage"
  })
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Custom Domain (optional)
resource "aws_apigatewayv2_domain_name" "main" {
  count       = var.custom_domain != "" ? 1 : 0
  domain_name = var.custom_domain

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# API Mapping for custom domain
resource "aws_apigatewayv2_api_mapping" "main" {
  count       = var.custom_domain != "" ? 1 : 0
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.main[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

# ==============================================================================
# CLOUDFRONT ORIGIN VERIFICATION (Lambda Authorizer)
# ==============================================================================
# When CloudFront is enabled, this Lambda Authorizer validates that requests
# contain the correct X-CloudFront-Secret header, preventing direct API access.

# IAM Role for Lambda Authorizer
resource "aws_iam_role" "cloudfront_authorizer" {
  count = var.enable_cloudfront_protection ? 1 : 0
  name  = "${var.name_prefix}-cloudfront-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda logging
resource "aws_iam_role_policy_attachment" "cloudfront_authorizer_logs" {
  count      = var.enable_cloudfront_protection ? 1 : 0
  role       = aws_iam_role.cloudfront_authorizer[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Authorizer function
resource "aws_lambda_function" "cloudfront_authorizer" {
  count         = var.enable_cloudfront_protection ? 1 : 0
  function_name = "${var.name_prefix}-cloudfront-authorizer"
  role          = aws_iam_role.cloudfront_authorizer[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 3
  memory_size   = 128

  filename         = data.archive_file.cloudfront_authorizer[0].output_path
  source_code_hash = data.archive_file.cloudfront_authorizer[0].output_base64sha256

  environment {
    variables = {
      CLOUDFRONT_SECRET = var.cloudfront_secret_header
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-authorizer"
  })
}

# Lambda function code
data "archive_file" "cloudfront_authorizer" {
  count       = var.enable_cloudfront_protection ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/cloudfront_authorizer.zip"

  source {
    content  = <<-PYTHON
import os

def handler(event, context):
    """
    Lambda Authorizer for API Gateway HTTP API.
    Validates that requests contain the correct CloudFront secret header.
    """
    expected_secret = os.environ.get('CLOUDFRONT_SECRET', '')

    # Get headers from the request
    headers = event.get('headers', {})

    # Check for the CloudFront secret header (case-insensitive)
    cloudfront_secret = headers.get('x-cloudfront-secret', '')

    # Log for debugging (redact actual secret)
    print(f"CloudFront header present: {bool(cloudfront_secret)}")
    print(f"Header matches expected: {cloudfront_secret == expected_secret}")

    # Return authorization decision
    if cloudfront_secret == expected_secret:
        return {
            "isAuthorized": True,
            "context": {
                "source": "cloudfront"
            }
        }
    else:
        return {
            "isAuthorized": False,
            "context": {
                "error": "Invalid or missing CloudFront secret header"
            }
        }
PYTHON
    filename = "index.py"
  }
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "cloudfront_authorizer" {
  count         = var.enable_cloudfront_protection ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudfront_authorizer[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

# API Gateway Authorizer
resource "aws_apigatewayv2_authorizer" "cloudfront" {
  count                             = var.enable_cloudfront_protection ? 1 : 0
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.cloudfront_authorizer[0].invoke_arn
  authorizer_payload_format_version = "2.0"
  name                              = "cloudfront-authorizer"
  enable_simple_responses           = true

  # Cache authorization for 5 minutes based on the secret header
  authorizer_result_ttl_in_seconds = 300
  identity_sources                  = ["$request.header.x-cloudfront-secret"]
}

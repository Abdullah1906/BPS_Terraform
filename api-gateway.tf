resource "aws_apigatewayv2_api" "bps" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]

    allow_methods = [
      "GET",
      "POST",
      "PUT",
      "DELETE",
      "PATCH",
      "OPTIONS"
    ]

    allow_headers = [
      "content-type",
      "authorization"
    ]

    max_age = 300
  }
}

resource "aws_apigatewayv2_vpc_link" "bps" {
  name = "${var.project_name}-${var.environment}-vpc-link"

  security_group_ids = [
    aws_security_group.vpc_link.id
  ]

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id = aws_apigatewayv2_api.bps.id

  integration_type = "HTTP_PROXY"
  integration_uri  = aws_lb_listener.api.arn

  integration_method = "ANY"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.bps.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id = aws_apigatewayv2_api.bps.id

  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id = aws_apigatewayv2_api.bps.id

  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.bps.id
  name        = "$default"
  auto_deploy = true
}

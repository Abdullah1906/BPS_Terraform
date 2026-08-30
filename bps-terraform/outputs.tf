output "api_gateway_url" {
  description = "Public API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_gateway_id" {
  value = aws_apigatewayv2_api.bps.id
}

output "internal_alb_dns" {
  value = aws_lb.api.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "sql_private_ip" {
  value = aws_instance.sql.private_ip
}

output "sql_secret_arn" {
  value     = aws_secretsmanager_secret.sql_credentials.arn
  sensitive = true
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "vpc_id" {
  value = aws_vpc.main.id
}

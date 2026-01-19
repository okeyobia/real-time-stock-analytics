output "aws_region" {
  description = "AWS region used for deployment"
  value       = var.aws_region
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "project_name" {
  description = "Project identifier"
  value       = var.project_name
}

output "default_tags" {
  description = "Tags applied to all AWS resources"
  value       = var.default_tags
}

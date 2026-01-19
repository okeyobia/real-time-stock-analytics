variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Logical name of the project used for tagging and naming"
  type        = string
  default     = "real-time-stock-analytics"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "default_tags" {
  description = "Default tags applied to all AWS resources"
  type        = map(string)
  default = {
    Project     = "real-time-stock-analytics"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

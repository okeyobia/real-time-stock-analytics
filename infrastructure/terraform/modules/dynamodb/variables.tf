variable "table_name" {
  type = string
}

variable "ttl_attribute" {
  type    = string
  default = "expires_at"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_zip" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "s3_bucket" {
  description = "Name of the S3 bucket"
  type        = string
}

// ...existing code...


variable "stock_api_key" {
  description = "Stock API key"
  type        = string
  sensitive   = true
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for processed stock data"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for historical stock data"
  type        = string
}


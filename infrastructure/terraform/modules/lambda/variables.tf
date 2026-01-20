variable "function_name" {
  type = string
}

variable "lambda_zip" {
  type = string
}

variable "kinesis_arn" {
  type = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for processed stock data"
  type = string
}

variable "dynamodb_arn" {
  type = string
}

variable "s3_bucket" {
  description = "S3 bucket for raw historical stock data"
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "kinesis_stream_name" {
  description = "Kinesis stream name used by the producer"
  type        = string
}

variable "stock_api_key" {
  description = "API key for the stock data provider"
  type        = string
  sensitive   = true
}

variable "stock_symbols" {
  description = "Comma-separated list of stock symbols"
  type        = string
}

variable "stock_api_secret_arn" {
  type = string
}

variable "lambda_alias" {
  description = "Lambda alias name"
  type        = string
  default     = "live"
}




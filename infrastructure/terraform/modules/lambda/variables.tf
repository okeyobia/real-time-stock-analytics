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
  type = string
}

variable "dynamodb_arn" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

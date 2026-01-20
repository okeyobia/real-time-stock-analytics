variable "bucket_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default = ""
}

// ...existing code...
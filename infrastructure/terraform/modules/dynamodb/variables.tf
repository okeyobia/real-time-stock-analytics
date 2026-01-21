variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "ttl_attribute" {
  description = "TTL attribute name"
  type        = string
  default     = "ttl"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
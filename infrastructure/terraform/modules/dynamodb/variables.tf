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

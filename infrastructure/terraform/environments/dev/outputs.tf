output "kinesis_stream_name" {
  value = module.kinesis.stream_name
}

output "dynamodb_table" {
  value = module.dynamodb.table_name
}

output "s3_bucket" {
  value = module.s3.bucket_name
}

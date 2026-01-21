output "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  value       = module.kinesis.stream_name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  value       = module.kinesis.stream_arn
}

output "dynamodb_table" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "s3_bucket" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "producer_lambda_function_name" {
  description = "Name of the producer Lambda function"
  value       = module.lambda.function_name
}

output "producer_lambda_function_arn" {
  description = "ARN of the producer Lambda function"
  value       = module.lambda.function_arn
}

output "processor_lambda_function_name" {
  description = "Name of the processor Lambda function"
  value       = module.processor_lambda.function_name
}

output "processor_lambda_function_arn" {
  description = "ARN of the processor Lambda function"
  value       = module.processor_lambda.function_arn
}
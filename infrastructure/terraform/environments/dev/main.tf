module "kinesis" {
  source          = "../../modules/kinesis"
  stream_name     = "stock-stream"
  shard_count     = 1
  retention_hours = 24
}

module "dynamodb" {
  source     = "../../modules/dynamodb"
  table_name = var.dynamodb_table_name
}

// ...existing code...
module "s3" {
  source      = "../../modules/s3"
  bucket_name = var.s3_bucket_name
  function_name = "stock-data-producer"  # Add this if S3 module requires it
}
// ...existing code...
module "lambda" {
  source            = "../../modules/lambda"
  function_name     = "stock-data-producer"
  lambda_zip        = "../../../services/producer/lambda.zip"

  kinesis_stream_name = module.kinesis.stream_name
  stock_api_key       = var.stock_api_key
  stock_symbols       = "AAPL,MSFT,GOOGL"

  kinesis_arn    = module.kinesis.stream_arn
  dynamodb_table = module.dynamodb.table_name
  dynamodb_arn   = module.dynamodb.table_arn
  s3_bucket      = module.s3.bucket_name
  s3_bucket_arn  = module.s3.bucket_arn
}

module "processor_lambda" {
  source = "../../modules/lambda"

  function_name = "stock-stream-processor"
  lambda_zip    = "../../../services/processor/lambda.zip"

  kinesis_stream_name = module.kinesis.stream_name
  stock_api_key       = var.stock_api_key
  stock_symbols       = ""

  kinesis_arn    = module.kinesis.stream_arn
  dynamodb_table = module.dynamodb.table_name
  dynamodb_arn   = module.dynamodb.table_arn
  s3_bucket      = module.s3.bucket_name
  s3_bucket_arn  = module.s3.bucket_arn
}

module "stock_api_secret" {
  source        = "../../modules/secrets"
  secret_name   = "stock-api-key-dev"
  secret_value  = var.stock_api_key
}


module "kinesis" {
  source          = "../../modules/kinesis"
  stream_name     = "stock-stream"
  shard_count     = 1
  retention_hours = 24
}

module "dynamodb" {
  source     = "../../modules/dynamodb"
  table_name = "stock-realtime"
}

module "s3" {
  source      = "../../modules/s3"
  bucket_name = "stock-historical-data-dev"
}

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


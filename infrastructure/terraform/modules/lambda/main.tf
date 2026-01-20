resource "aws_lambda_function" "this" {
  function_name = var.function_name
  publish = true
  runtime       = "python3.11"
  handler       = "app.handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = var.lambda_zip
  source_code_hash = filebase64sha256(var.lambda_zip)

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table
      S3_BUCKET      = var.s3_bucket
      KINESIS_STREAM_NAME = var.kinesis_stream_name
      STOCK_API_KEY       = var.stock_api_key
      STOCK_SYMBOLS       = var.stock_symbols
      STOCK_API_SECRET_ARN = var.stock_api_secret_arn
    }
  }

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "kinesis" {
  event_source_arn  = var.kinesis_arn
  function_name     = aws_lambda_function.this.arn
  starting_position = "LATEST"
  batch_size        = 100
}

resource "aws_lambda_alias" "live" {
  name             = var.lambda_alias
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}


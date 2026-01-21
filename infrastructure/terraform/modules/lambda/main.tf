resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}

resource "aws_s3_object" "lambda_zip" {
  bucket = var.s3_bucket
  key    = "lambda/${var.function_name}.zip"
  source = var.lambda_zip
  etag   = filemd5(var.lambda_zip)
}

resource "aws_s3_object" "lambda_layer" {
  bucket = var.s3_bucket
  key    = "lambda/${var.function_name}-layer.zip"
  source = var.lambda_layer_zip
  etag   = filemd5(var.lambda_layer_zip)
}

resource "aws_lambda_layer_version" "dependencies" {
  layer_name          = "${var.function_name}-dependencies"
  s3_bucket           = var.s3_bucket
  s3_key              = aws_s3_object.lambda_layer.key
  compatible_runtimes = ["python3.11"]
  source_code_hash    = filebase64sha256(var.lambda_layer_zip)
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

  s3_bucket        = var.s3_bucket
  s3_key           = aws_s3_object.lambda_zip.key
  source_code_hash = filebase64sha256(var.lambda_zip)

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      KINESIS_STREAM_NAME  = var.kinesis_stream_name
      STOCK_API_KEY        = var.stock_api_key
      STOCK_SYMBOLS        = var.stock_symbols
      DYNAMODB_TABLE       = var.dynamodb_table
      S3_BUCKET            = var.s3_bucket
      STOCK_API_SECRET_ARN = var.stock_api_secret_arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach,
    aws_cloudwatch_log_group.lambda_log_group
  ]
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
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.function_name}-dlq"
  message_retention_seconds = 1209600 # 14 days
  
  tags = {
    Name = "${var.function_name}-dlq"
  }
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

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

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

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.dlq.arn
    }
  }
}

resource "aws_lambda_alias" "live" {
  name             = var.lambda_alias
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors lambda throttles"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 50000
  alarm_description   = "This metric monitors lambda execution duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.function_name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors messages in DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}
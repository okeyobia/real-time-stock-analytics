resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "symbol"
  range_key = "timestamp"

  attribute {
    name = "symbol"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  runtime       = "python3.11"
  handler       = "app.handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = var.lambda_zip
  source_code_hash = filebase64sha256(var.lambda_zip)

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table
      S3_BUCKET      = var.s3_bucket
    }
  }

  tags = var.tags
}

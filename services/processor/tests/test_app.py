import base64
import json
import os
from unittest.mock import MagicMock, patch

import boto3
import pytest
from moto import mock_aws

from app import handler


@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def dynamodb_table(aws_credentials):
    with mock_aws():
        client = boto3.client("dynamodb", region_name="us-east-1")
        client.create_table(
            TableName="test-table",
            KeySchema=[{"AttributeName": "symbol", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "symbol", "AttributeType": "S"}],
            ProvisionedThroughput={"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
        )
        yield "test-table"


@pytest.fixture
def s3_bucket(aws_credentials):
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="test-bucket")
        yield "test-bucket"


def create_kinesis_event(records):
    """Helper function to create a Kinesis event."""
    return {
        "Records": [
            {
                "kinesis": {
                    "data": base64.b64encode(json.dumps(record).encode("utf-8")).decode(
                        "utf-8"
                    )
                }
            }
            for record in records
        ]
    }


def test_handler_success(dynamodb_table, s3_bucket):
    # Sample Kinesis event data
    stock_data = {"symbol": "GOOG", "price": 2800.0, "timestamp": "2024-01-01T00:00:00Z"}
    event = create_kinesis_event([stock_data])

    with patch("boto3.resource") as mock_boto_resource, patch(
        "boto3.client"
    ) as mock_boto_client:
        # Mock DynamoDB and S3
        mock_dynamodb = MagicMock()
        mock_s3 = MagicMock()
        mock_boto_resource.side_effect = [mock_dynamodb, mock_s3]

        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table

        # Set environment variables
        os.environ["DYNAMODB_TABLE_NAME"] = dynamodb_table
        os.environ["S3_BUCKET_NAME"] = s3_bucket

        # Call the handler
        handler(event, {})

        # Assert DynamoDB was called correctly
        mock_table.put_item.assert_called_once()
        item_put = mock_table.put_item.call_args[1]["Item"]
        assert item_put["symbol"] == "GOOG"
        assert item_put["price"] == 2800.0

        # Assert S3 was called correctly
        mock_s3.put_object.assert_called_once()
        s3_args = mock_s3.put_object.call_args[1]
        assert s3_args["Bucket"] == s3_bucket
        assert "year=" in s3_args["Key"]
        assert "month=" in s3_args["Key"]
        assert "day=" in s3_args["Key"]


def test_handler_bad_record():
    # A record that is not valid JSON
    bad_record = {"kinesis": {"data": base64.b64encode(b"not-json").decode("utf-8")}}
    event = {"Records": [bad_record]}

    # The handler should log an error and not raise an exception
    try:
        handler(event, {})
    except Exception as e:
        pytest.fail(f"Handler raised an unexpected exception: {e}")


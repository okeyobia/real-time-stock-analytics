import json
import os
from unittest.mock import patch, MagicMock

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
def kinesis_stream(aws_credentials):
    with mock_aws():
        client = boto3.client("kinesis", region_name="us-east-1")
        client.create_stream(StreamName="test-stream", ShardCount=1)
        yield "test-stream"


@patch("app.get_stock_price")
def test_handler_success(mock_get_stock_price, kinesis_stream):
    # Mock the stock price API response
    mock_get_stock_price.return_value = {
        "symbol": "AAPL",
        "price": 150.0,
        "timestamp": "2024-01-01T00:00:00Z",
    }

    # Mock the Kinesis client
    with patch("boto3.client") as mock_boto_client:
        mock_kinesis = MagicMock()
        mock_boto_client.return_value = mock_kinesis

        # Set environment variables
        os.environ["KINESIS_STREAM_NAME"] = kinesis_stream

        # Call the handler
        event = {}
        context = {}
        handler(event, context)

        # Assert that the Kinesis client was called correctly
        mock_kinesis.put_record.assert_called_once()
        call_args = mock_kinesis.put_record.call_args[1]
        assert call_args["StreamName"] == kinesis_stream
        
        data = json.loads(call_args["Data"])
        assert data["symbol"] == "AAPL"
        assert data["price"] == 150.0
        
        assert "event_time" in data
        assert "request_id" in data

@patch("app.get_stock_price")
def test_handler_api_failure(mock_get_stock_price, kinesis_stream):
    # Mock the stock price API to raise an exception
    mock_get_stock_price.side_effect = Exception("API Error")

    with patch("boto3.client") as mock_boto_client:
        mock_kinesis = MagicMock()
        mock_boto_client.return_value = mock_kinesis

        os.environ["KINESIS_STREAM_NAME"] = kinesis_stream

        # The handler should not raise an exception, but log the error
        try:
            handler({}, {})
        except Exception as e:
            pytest.fail(f"Handler raised an unexpected exception: {e}")
        
        # Assert that Kinesis was not called
        mock_kinesis.put_record.assert_not_called()


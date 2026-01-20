import json
import logging
import os
import random
import time
from typing import Dict, List

import boto3
from botocore.exceptions import ClientError, BotoCoreError

# ----------------------------
# Configuration
# ----------------------------
KINESIS_STREAM_NAME = os.getenv("KINESIS_STREAM_NAME", "stock-stream")
STOCK_API_KEY = os.getenv("STOCK_API_KEY", "mock-api-key")
STOCK_SYMBOLS = os.getenv("STOCK_SYMBOLS", "AAPL,MSFT,GOOGL").split(",")

MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 2

# ----------------------------
# Logging
# ----------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ----------------------------
# AWS Clients
# ----------------------------
kinesis_client = boto3.client("kinesis")

# ----------------------------
# Mock / API Fetch
# ----------------------------
def fetch_stock_price(symbol: str) -> Dict:
    """
    Fetch stock price data from a public API.
    This implementation mocks the response to keep the Lambda testable
    and free-tier friendly.
    """
    # Simulated API latency
    time.sleep(0.1)

    # Mocked response (replace with real API if desired)
    return {
        "symbol": symbol,
        "price": round(random.uniform(100, 500), 2),
        "volume": random.randint(1_000, 5_000_000),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

# ----------------------------
# Kinesis Publish
# ----------------------------
def put_record_to_kinesis(record: Dict) -> None:
    """
    Publish a single record to Kinesis with retries.
    """
    payload = json.dumps(record)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = kinesis_client.put_record(
                StreamName=KINESIS_STREAM_NAME,
                Data=payload,
                PartitionKey=record["symbol"]
            )

            logger.info(
                "Successfully published record",
                extra={
                    "symbol": record["symbol"],
                    "sequence_number": response["SequenceNumber"],
                    "shard_id": response["ShardId"]
                }
            )
            return

        except (ClientError, BotoCoreError) as error:
            logger.error(
                "Failed to publish record",
                extra={
                    "symbol": record["symbol"],
                    "attempt": attempt,
                    "error": str(error)
                }
            )

            if attempt == MAX_RETRIES:
                raise

            time.sleep(RETRY_BACKOFF_SECONDS ** attempt)

# ----------------------------
# Lambda Handler
# ----------------------------
def handler(event, context):
    """
    Lambda entry point.
    Fetches stock prices and publishes them to Kinesis.
    """
    logger.info(
        "Stock producer invocation started",
        extra={"symbols": STOCK_SYMBOLS}
    )

    published = 0
    failed = 0

    for symbol in STOCK_SYMBOLS:
        try:
            stock_data = fetch_stock_price(symbol)
            put_record_to_kinesis(stock_data)
            published += 1

        except Exception as exc:
            failed += 1
            logger.exception(
                "Unhandled error while processing symbol",
                extra={"symbol": symbol, "error": str(exc)}
            )

    logger.info(
        "Stock producer invocation completed",
        extra={
            "published": published,
            "failed": failed
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "published": published,
            "failed": failed
        })
    }

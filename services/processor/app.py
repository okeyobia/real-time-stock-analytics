import base64
import json
import logging
import os
from collections import defaultdict, deque
from datetime import datetime
from typing import Dict, Any, List, Optional

import boto3
from botocore.exceptions import ClientError, BotoCoreError
from pythonjsonlogger import jsonlogger

# =====================================================
# Configuration
# =====================================================
DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
S3_BUCKET = os.environ["S3_BUCKET"]
SECRET_NAME = os.environ.get("SECRET_NAME", "stock-api-key-dev")

MOVING_AVG_WINDOW = 5

# =====================================================
# Logging (Structured)
# =====================================================
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Clear any existing handlers
if logger.handlers:
    for handler in logger.handlers:
        logger.removeHandler(handler)

logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)


def log(message: str, level: str = "info", **kwargs):
    """Structured logging helper"""
    log_data = {"message": message, **kwargs}
    
    if level == "error":
        logger.error(log_data)
    elif level == "warning":
        logger.warning(log_data)
    else:
        logger.info(log_data)


# =====================================================
# AWS Clients
# =====================================================
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(DYNAMODB_TABLE)

s3 = boto3.client("s3")
secrets_manager = boto3.client("secretsmanager")

# =====================================================
# Secrets Management
# =====================================================
_secret_cache: Optional[Dict[str, Any]] = None


def get_secret() -> Dict[str, Any]:
    """Retrieve and cache secrets from AWS Secrets Manager."""
    global _secret_cache
    
    if _secret_cache is not None:
        return _secret_cache
    
    try:
        response = secrets_manager.get_secret_value(SecretId=SECRET_NAME)
        
        if "SecretString" in response:
            _secret_cache = json.loads(response["SecretString"])
        else:
            _secret_cache = json.loads(base64.b64decode(response["SecretBinary"]))
        
        log("Secret retrieved successfully", secret_name=SECRET_NAME)
        return _secret_cache
        
    except ClientError as err:
        log("Failed to retrieve secret", level="error", error=str(err), 
            error_type=type(err).__name__, secret_name=SECRET_NAME)
        raise


# =====================================================
# In-memory state (warm Lambda only)
# =====================================================
price_cache: Dict[str, deque] = defaultdict(
    lambda: deque(maxlen=MOVING_AVG_WINDOW)
)


# =====================================================
# Helpers
# =====================================================
def decode_kinesis_record(record: Dict[str, Any]) -> Dict[str, Any]:
    payload = base64.b64decode(record["kinesis"]["data"]).decode("utf-8")
    return json.loads(payload)


def calculate_moving_average(symbol: str, price: float) -> float:
    prices = price_cache[symbol]
    prices.append(price)
    return round(sum(prices) / len(prices), 2)


def write_to_dynamodb(item: Dict[str, Any]):
    try:
        table.put_item(Item=item)
        log("DynamoDB write successful", 
            symbol=item.get("symbol"), 
            timestamp=item.get("timestamp"))
    except Exception as err:
        log("DynamoDB write failed", level="error", 
            error=str(err), error_type=type(err).__name__)
        raise


def write_to_s3(raw_event: Dict[str, Any], event_time: datetime):
    key = (
        f"year={event_time.year}/"
        f"month={event_time.month:02d}/"
        f"day={event_time.day:02d}/"
        f"{raw_event['symbol']}-{event_time.isoformat()}.json"
    )

    try:
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=json.dumps(raw_event).encode("utf-8"),
            ContentType="application/json"
        )
        log("S3 write successful", 
            bucket=S3_BUCKET, 
            key=key, 
            symbol=raw_event.get("symbol"))
    except Exception as err:
        log("S3 write failed", level="error", 
            error=str(err), error_type=type(err).__name__, 
            bucket=S3_BUCKET, key=key)
        raise


# =====================================================
# Lambda Handler (Partial Batch Failure Enabled)
# =====================================================
def handler(event, context):
    batch_failures: List[Dict[str, str]] = []
    
    log("Lambda invocation started", 
        function="processor",
        request_id=context.request_id,
        event_records=len(event.get('Records', [])))
    
    # Load secrets on cold start
    try:
        secrets = get_secret()
        log("Secrets loaded successfully", has_api_key=bool(secrets.get("api_key")))
    except Exception as err:
        log("Failed to load secrets - continuing without", level="warning",
            error=str(err), error_type=type(err).__name__)

    successful_records = 0
    failed_records = 0

    for record in event["Records"]:
        record_id = record["eventID"]

        try:
            data = decode_kinesis_record(record)

            symbol = data["symbol"]
            price = float(data["price"])
            volume = int(data["volume"])
            timestamp = data["timestamp"]

            event_time = datetime.fromisoformat(
                timestamp.replace("Z", "+00:00")
            )

            moving_avg = calculate_moving_average(symbol, price)

            processed_item = {
                "symbol": symbol,
                "timestamp": timestamp,
                "price": price,
                "volume": volume,
                "moving_average": moving_avg
            }

            write_to_dynamodb(processed_item)
            write_to_s3(data, event_time)

            log("Record processed successfully",
                symbol=symbol,
                price=price,
                volume=volume,
                moving_average=moving_avg,
                record_id=record_id)
            
            successful_records += 1

        except (KeyError, ValueError) as err:
            log("Invalid record format", level="error",
                error=str(err),
                error_type=type(err).__name__,
                record_id=record_id)
            batch_failures.append({"itemIdentifier": record_id})
            failed_records += 1

        except (ClientError, BotoCoreError) as err:
            log("AWS service error", level="error",
                error=str(err),
                error_type=type(err).__name__,
                record_id=record_id)
            batch_failures.append({"itemIdentifier": record_id})
            failed_records += 1

        except Exception as err:
            log("Unexpected error", level="error",
                error=str(err),
                error_type=type(err).__name__,
                record_id=record_id,
                exc_info=True)
            batch_failures.append({"itemIdentifier": record_id})
            failed_records += 1

    log("Lambda invocation completed",
        function="processor",
        request_id=context.request_id,
        total_records=len(event.get('Records', [])),
        successful_records=successful_records,
        failed_records=failed_records)

    return {
        "batchItemFailures": batch_failures
    }
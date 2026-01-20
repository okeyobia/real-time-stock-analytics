import base64
import json
import logging
import os
from collections import defaultdict, deque
from datetime import datetime
from typing import Dict, Any, List, Optional

import boto3
from botocore.exceptions import ClientError, BotoCoreError

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

def log(message: str, **kwargs):
    logger.info(json.dumps({"message": message, **kwargs}))

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
        log("Failed to retrieve secret", error=str(err), secret_name=SECRET_NAME)
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
    table.put_item(Item=item)

def write_to_s3(raw_event: Dict[str, Any], event_time: datetime):
    key = (
        f"year={event_time.year}/"
        f"month={event_time.month:02d}/"
        f"day={event_time.day:02d}/"
        f"{raw_event['symbol']}-{event_time.isoformat()}.json"
    )

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=key,
        Body=json.dumps(raw_event).encode("utf-8"),
        ContentType="application/json"
    )

# =====================================================
# Lambda Handler (Partial Batch Failure Enabled)
# =====================================================
def handler(event, context):
    batch_failures: List[Dict[str, str]] = []
    
    # Load secrets on cold start
    try:
        secrets = get_secret()
        log("Secrets loaded", has_api_key=bool(secrets.get("api_key")))
    except Exception as err:
        log("Failed to load secrets", error=str(err))
        # Optionally fail fast if secrets are critical
        # raise

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

            log(
                "Record processed successfully",
                symbol=symbol,
                price=price,
                moving_average=moving_avg
            )

        except (KeyError, ValueError) as err:
            log(
                "Invalid record format",
                error=str(err),
                record_id=record_id
            )
            batch_failures.append({"itemIdentifier": record_id})

        except (ClientError, BotoCoreError, Exception) as err:
            log(
                "Processing failure",
                error=str(err),
                record_id=record_id
            )
            batch_failures.append({"itemIdentifier": record_id})

    return {
        "batchItemFailures": batch_failures
    }
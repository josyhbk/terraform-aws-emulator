"""Items API behind API Gateway (HTTP API, payload format 2.0).

GET  /items  list items
POST /items  create an item from a JSON body
"""

import base64
import json
import os
import uuid

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE"])


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    if event["requestContext"]["http"]["method"] == "GET":
        return response(200, table.scan(Limit=100)["Items"])

    body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body)
    try:
        data = json.loads(body)
    except ValueError:
        return response(400, {"error": "body must be JSON"})
    if not isinstance(data, dict) or not isinstance(data.get("name"), str):
        return response(400, {"error": "name is required"})

    item = {"id": str(uuid.uuid4()), "name": data["name"][:200]}
    table.put_item(Item=item)
    return response(201, item)

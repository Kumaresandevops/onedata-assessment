"""
app_lambda/handler.py

Connects to Aurora PostgreSQL using credentials retrieved at runtime
from Secrets Manager (via VPC endpoint — no NAT required).

Logs a SUCCESS message to CloudWatch — never logs the password.
"""

import json
import logging
import os

import boto3
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SECRET_ARN = os.environ["SECRET_ARN"]
AWS_REGION  = os.environ.get("AWS_REGION", "us-east-1")


def _get_secret() -> dict:
    """Retrieve and parse the DB secret from Secrets Manager."""
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    response = client.get_secret_value(SecretId=SECRET_ARN)
    return json.loads(response["SecretString"])


def handler(event, context):
    """Lambda entry point."""
    logger.info("Retrieving database credentials from Secrets Manager...")

    secret = _get_secret()

    host     = secret["host"]
    port     = int(secret.get("port", 5432))
    dbname   = secret["dbname"]
    username = secret["username"]
    password = secret["password"]   # used for connection only — never logged

    logger.info("Credentials retrieved. Connecting to Aurora at %s:%s/%s as user '%s'",
                host, port, dbname, username)

    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            dbname=dbname,
            user=username,
            password=password,
            connect_timeout=10,
            sslmode="require",
        )

        with conn.cursor() as cur:
            cur.execute("SELECT version();")
            version = cur.fetchone()[0]

        conn.close()

        logger.info("SUCCESS: Connected to Aurora PostgreSQL. Server version: %s", version)
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Database connection successful",
                "db_version": version,
            }),
        }

    except Exception as exc:
        logger.error("FAILURE: Could not connect to Aurora — %s", str(exc))
        raise

"""
rotation_lambda/handler.py

Secrets Manager rotation handler for an Aurora PostgreSQL master password.
Implements the four-step rotation protocol required by AWS.

Steps:
  createSecret  – generate a new password and store it as AWSPENDING
  setSecret     – apply AWSPENDING credentials to the database
  testSecret    – verify AWSPENDING credentials work
  finishSecret  – promote AWSPENDING → AWSCURRENT
"""

import json
import logging
import os
import string
import secrets as _secrets_module

import boto3
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


def _sm_client():
    return boto3.client("secretsmanager", region_name=AWS_REGION)


def _get_secret_dict(client, secret_id: str, stage: str, token: str | None = None) -> dict:
    kwargs = {"SecretId": secret_id, "VersionStage": stage}
    if token:
        kwargs["VersionId"] = token
    response = client.get_secret_value(**kwargs)
    return json.loads(response["SecretString"])


def _generate_password(length: int = 32) -> str:
    alphabet = string.ascii_letters + string.digits + "!#$%&*()-_=+[]{}<>:?"
    return "".join(_secrets_module.choice(alphabet) for _ in range(length))


def handler(event, context):
    """Entry point called by Secrets Manager for each rotation step."""
    arn   = event["SecretId"]
    token = event["ClientRequestToken"]
    step  = event["Step"]

    client = _sm_client()

    # Validate the secret exists and rotation is enabled
    metadata = client.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Rotation is not enabled for secret {arn}")

    versions = metadata.get("VersionIdsToStages", {})
    if token not in versions:
        raise ValueError(f"Secret version {token} not found for secret {arn}")

    if "AWSCURRENT" in versions[token]:
        logger.info("Token %s is already AWSCURRENT — skipping rotation", token)
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"Token {token} is not AWSPENDING for secret {arn}")

    dispatch = {
        "createSecret":  _create_secret,
        "setSecret":     _set_secret,
        "testSecret":    _test_secret,
        "finishSecret":  _finish_secret,
    }
    if step not in dispatch:
        raise ValueError(f"Unknown rotation step: {step}")

    dispatch[step](client, arn, token)


# ── Step 1 ────────────────────────────────────────────────────────────────────
def _create_secret(client, arn: str, token: str):
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("AWSPENDING already exists for token %s — nothing to do", token)
        return
    except client.exceptions.ResourceNotFoundException:
        pass

    current = _get_secret_dict(client, arn, "AWSCURRENT")
    current["password"] = _generate_password()

    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(current),
        VersionStages=["AWSPENDING"],
    )
    logger.info("createSecret: stored AWSPENDING version for token %s", token)


# ── Step 2 ────────────────────────────────────────────────────────────────────
def _set_secret(client, arn: str, token: str):
    current = _get_secret_dict(client, arn, "AWSCURRENT")
    pending = _get_secret_dict(client, arn, "AWSPENDING", token)

    conn = psycopg2.connect(
        host=current["host"],
        port=int(current.get("port", 5432)),
        dbname=current["dbname"],
        user=current["username"],
        password=current["password"],
        connect_timeout=10,
        sslmode="require",
    )
    conn.autocommit = True

    try:
        with conn.cursor() as cur:
            cur.execute(
                "ALTER USER %s WITH PASSWORD %%s" % pending["username"],
                (pending["password"],),
            )
        logger.info("setSecret: database password updated for user '%s'", pending["username"])
    finally:
        conn.close()


# ── Step 3 ────────────────────────────────────────────────────────────────────
def _test_secret(client, arn: str, token: str):
    pending = _get_secret_dict(client, arn, "AWSPENDING", token)

    conn = psycopg2.connect(
        host=pending["host"],
        port=int(pending.get("port", 5432)),
        dbname=pending["dbname"],
        user=pending["username"],
        password=pending["password"],
        connect_timeout=10,
        sslmode="require",
    )

    with conn.cursor() as cur:
        cur.execute("SELECT 1")

    conn.close()
    logger.info("testSecret: AWSPENDING credentials verified successfully")


# ── Step 4 ────────────────────────────────────────────────────────────────────
def _finish_secret(client, arn: str, token: str):
    metadata   = client.describe_secret(SecretId=arn)
    current_id = next(
        vid for vid, stages in metadata["VersionIdsToStages"].items()
        if "AWSCURRENT" in stages
    )

    if current_id == token:
        logger.info("finishSecret: token is already AWSCURRENT — done")
        return

    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_id,
    )
    logger.info("finishSecret: promoted token %s to AWSCURRENT", token)

import json
import logging
import os
import pathlib
import sys
import time

import boto3
import botocore
import psycopg2
import watchtower

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ENV vars
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SECRET_NAME = os.environ["RDS_SECRET_NAME"]
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL_SECONDS", "5"))
HEARTBEAT_INTERVAL = int(os.environ.get("HEARTBEAT_INTERVAL_SECONDS", "300"))
FORCE_CRITICAL_CRASH = os.environ.get("FORCE_CRITICAL_CRASH", "false").lower() == "true"

logger.addHandler(
    watchtower.CloudWatchLogHandler(
        log_group="/videoclub/rating-worker",
        boto3_client=boto3.client("logs", region_name=AWS_REGION),
    )
)

cloudwatch_metrics = boto3.client("cloudwatch", region_name=AWS_REGION)


def get_secret():
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    try:
        response = client.get_secret_value(SecretId=SECRET_NAME)
    except botocore.exceptions.ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "ResourceNotFoundException":
            msg = f"El secreto '{SECRET_NAME}' no existe en Secrets Manager"
        elif error_code == "AccessDeniedException":
            msg = f"Sin permisos para acceder al secreto '{SECRET_NAME}'"
        else:
            msg = f"Error al obtener credenciales: {error_code}"
        logger.error(msg)
        raise Exception
    except botocore.exceptions.NoCredentialsError as e:
        logger.error(f"Error getting secret: {e}")
        raise Exception
    return json.loads(response["SecretString"])


def get_db_connection():
    secret = get_secret()
    return psycopg2.connect(
        host=secret["host"],
        port=secret.get("port", 5432),
        dbname=secret["dbname"],
        user=secret["username"],
        password=secret["password"],
    )


def process_message(message, conn):
    body = json.loads(message["Body"])
    movie_id = body["movie_id"]
    user_id = body["user_id"]
    rating = body["rating"]
    review = body.get("review")

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO ratings (movie_id, user_id, rating, review)
            VALUES (%s, %s, %s, %s)
        """,
            (movie_id, user_id, rating, review),
        )
        conn.commit()

    time.sleep(0.5)  # simula procesamiento lento
    logger.info(
        f"Rating guardado: movie_id={movie_id} user_id={user_id} rating={rating}"
    )


def poll():
    logger.info("start poll")
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info("got sqs")
    try:
        conn = get_db_connection()
        logger.info("connected to db")
    except Exception as e:
        logger.error(f"Cannot establish DB connection: {e}")
        sys.exit(1)

    logger.info("Worker iniciado, escuchando rating-requests...")

    if FORCE_CRITICAL_CRASH:
        logger.error("FORCE_CRITICAL_CRASH activado")
        raise Exception("FORCE_CRITICAL_CRASH")

    last_heartbeat = 0
    while True:
        pathlib.Path("/tmp/worker-alive").touch()

        now = time.time()
        if now - last_heartbeat >= HEARTBEAT_INTERVAL:
            cloudwatch_metrics.put_metric_data(
                Namespace="Videoclub",
                MetricData=[
                    {"MetricName": "WorkerHeartbeat", "Value": 1, "Unit": "Count"}
                ],
            )
            last_heartbeat = now

        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL, MaxNumberOfMessages=10, WaitTimeSeconds=10
        )

        messages = response.get("Messages", [])
        if not messages:
            logger.info("Queue vacía, esperando...")
            time.sleep(POLL_INTERVAL)
            continue

        for message in messages:
            try:
                process_message(message, conn)
                sqs.delete_message(
                    QueueUrl=SQS_QUEUE_URL, ReceiptHandle=message["ReceiptHandle"]
                )
            except Exception as e:
                logger.error(f"Error procesando mensaje: {e}")
                # No eliminamos el mensaje para que vuelva a la queue
                # después de que expire el visibility timeout

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    poll()

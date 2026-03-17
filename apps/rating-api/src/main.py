import os
import json
import logging
import boto3
import psycopg2
import botocore

from fastapi import FastAPI
from pydantic import BaseModel, field_validator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# ENV vars
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SECRET_NAME   = os.environ["RDS_SECRET_NAME"]
AWS_REGION    = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")


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
        password=secret["password"]
    )


class RatingRequest(BaseModel):
    movie_id: int
    user_id:  int
    rating:   int
    review:   str | None = None

    @field_validator("rating")
    @classmethod
    def rating_range(cls, v):
        if not 1 <= v <= 5:
            raise ValueError("rating debe ser entre 1 y 5")
        return v

    @field_validator("review")
    @classmethod
    def review_length(cls, v):
        if v is not None and len(v) > 500:
            raise ValueError("review no puede superar 500 caracteres")
        return v


@app.post("/rating")
def submit_rating(request: RatingRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM movies WHERE movie_id = %s", (request.movie_id,))
            if cur.fetchone() is None:
                logger.warning(f"movie_id {request.movie_id} no existe, transaccion descartada")
                return {"status": "discarded", "reason": "movie not found"}

            cur.execute("SELECT 1 FROM users WHERE user_id = %s", (request.user_id,))
            if cur.fetchone() is None:
                logger.warning(f"user_id {request.user_id} no existe, transaccion descartada")
                return {"status": "discarded", "reason": "user not found"}
    finally:
        conn.close()

    sqs = boto3.client("sqs", region_name=AWS_REGION)
    sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps({
            "movie_id": request.movie_id,
            "user_id":  request.user_id,
            "rating":   request.rating,
            "review":   request.review
        })
    )
    logger.info(f"Rating encolado: movie_id={request.movie_id} user_id={request.user_id} rating={request.rating}")
    return {"status": "enqueued"}

@app.get("/ratings/{movie_id}")
def get_ratings(movie_id: int):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Verificar que el movie existe
            cur.execute("SELECT title FROM movies WHERE movie_id = %s", (movie_id,))
            movie = cur.fetchone()
            if movie is None:
                return {"status": "not found", "movie_id": movie_id}

            # Obtener ratings
            cur.execute("""
                SELECT user_id, rating, review, created_at
                FROM ratings
                WHERE movie_id = %s
                ORDER BY created_at DESC
            """, (movie_id,))
            rows = cur.fetchall()

            return {
                "movie_id": movie_id,
                "title": movie[0],
                "total_ratings": len(rows),
                "ratings": [
                    {
                        "user_id": r[0],
                        "rating": r[1],
                        "review": r[2],
                        "created_at": r[3].isoformat()
                    }
                    for r in rows
                ]
            }
    finally:
        conn.close()

@app.get("/health")
def health():
    return {"status": "ok"}

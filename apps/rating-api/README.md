# rating-api

## Docker


```
docker build -t rating-api:latest .

docker run \
    --rm  \
    -p 8080:8080 \
    -v ~/.aws:/root/.aws:ro \
    -e SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/<aws-account>/rating-requests" \
    -e RDS_SECRET_NAME="videoclub/rds/credentials" \
    -e AWS_DEFAULT_REGION="us-east-1" \
    rating-api:latest
```

Probar local

```
# Health check
curl http://localhost:8080/health

# Enviar un rating
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 1, "rating": 5, "review": "Excelente película"}'

# Enviar un rating sin review
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 1, "rating": 3}'

# Ver ratings de una película
curl http://localhost:8080/ratings/1

# Casos de error — movie no existe
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 99999, "user_id": 1, "rating": 4}'

# Casos de error — user no existe
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 99999, "rating": 4}'

# Casos de error — rating fuera de rango
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 1, "rating": 6}'

# Casos de error — review demasiado larga
curl -X POST http://localhost:8080/rating \
  -H "Content-Type: application/json" \
  -d "{\"movie_id\": 1, \"user_id\": 1, \"rating\": 4, \"review\": \"$(python3 -c 'print("x"*501)')\"}"
```

## Docker Hub

```
docker build -t $DOCKER_HUB_USER/rating-api:latest .
docker push $DOCKER_HUB_USER/rating-api:latest

docker build -t $DOCKER_HUB_USER/rating-api:v1.0 .
docker push $DOCKER_HUB_USER/rating-api:v1.0
```

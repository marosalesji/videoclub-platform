# rating-worker

## Docker


```
docker build -t rating-worker:latest .

docker run \
    --rm  \
    -p 8080:8080 \
    -v ~/.aws:/root/.aws:ro \
    -e SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/${AWS_ACCOUNT}/rating-requests" \
    -e RDS_SECRET_NAME="videoclub/rds/credentials" \
    -e AWS_DEFAULT_REGION="us-east-1" \
    rating-worker:latest
```

## Docker Hub

```
docker build -t $DOCKER_HUB_USER/rating-worker:latest .
docker push $DOCKER_HUB_USER/rating-worker:latest

docker build -t $DOCKER_HUB_USER/rating-worker:v1.0 .
docker push $DOCKER_HUB_USER/rating-worker:v1.0
```

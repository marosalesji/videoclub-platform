#!/bin/bash
set -e

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo "=== Teardown de alarmas y SNS ==="
echo ""

# alarmas de rating-api (db-error-rate, cpu) y rating-worker (heartbeat)
echo "[1/2] Borrando alarmas videoclub-*..."
ALARM_NAMES=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "videoclub-" \
  --region "$REGION" \
  --query "MetricAlarms[].AlarmName" \
  --output text)

if [[ -z "$ALARM_NAMES" ]]; then
  echo "      No hay alarmas que borrar"
else
  aws cloudwatch delete-alarms \
    --alarm-names $ALARM_NAMES \
    --region "$REGION"
  echo "      Borradas: $ALARM_NAMES"
fi

# SNS topic
echo "[2/2] Borrando SNS topic videoclub-alerts..."
TOPIC_ARN=$(aws sns list-topics \
  --region "$REGION" \
  --query "Topics[?ends_with(TopicArn, ':videoclub-alerts')].TopicArn" \
  --output text)

if [[ -z "$TOPIC_ARN" ]]; then
  echo "      No existe el topic videoclub-alerts"
else
  aws sns delete-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION"
  echo "      Borrado: $TOPIC_ARN"
fi

echo ""
echo "=== Teardown completo ==="

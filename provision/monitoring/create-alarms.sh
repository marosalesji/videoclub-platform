#!/bin/bash
set -e

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

if [[ -z "${ALERT_EMAIL}" ]]; then
  echo "Error: ALERT_EMAIL no está definido"
  echo "Uso: ALERT_EMAIL=tu@correo.com ./create-alarms.sh"
  exit 1
fi
EMAIL="${ALERT_EMAIL}"

echo "=== Creando infraestructura de alarmas ==="
echo ""

# SNS topic
echo "[1/4] SNS topic"
TOPIC_ARN=$(aws sns create-topic \
  --name videoclub-alerts \
  --region "$REGION" \
  --query TopicArn \
  --output text)
echo "      ARN: $TOPIC_ARN"

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$EMAIL" \
  --region "$REGION" > /dev/null
echo "      ** Revisa $EMAIL y confirma la suscripción o las notificaciones no llegarán **"
echo ""

# --- rating-api ---

# Alarma: DB error rate > 30% (metric math)
echo "[2/4] Alarma: DB error rate (rating-api)"

# Estructura de métricas para cálculo de error rate
# MetricDataQuery en la documentacion
DB_METRICS='[
  {"Id":"errors","MetricStat":{"Metric":{"Namespace":"Videoclub","MetricName":"DBErrors"},"Period":30,"Stat":"Sum"},"ReturnData":false},
  {"Id":"requests","MetricStat":{"Metric":{"Namespace":"Videoclub","MetricName":"DBRequests"},"Period":30,"Stat":"Sum"},"ReturnData":false},
  {"Id":"rate","Expression":"errors/requests*100","Label":"DB Error Rate %","ReturnData":true}
]'
aws cloudwatch put-metric-alarm \
  --alarm-name "videoclub-db-error-rate" \
  --alarm-description "Tasa de errores de DB supera el 30%" \
  --metrics "$DB_METRICS" \
  --comparison-operator GreaterThanThreshold \
  --threshold 30 \
  --evaluation-periods 1 \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

# Alarma: CPU > 70% por instancia EC2
# cluster de k8s, se filtra por tag name
echo "[3/4] Alarmas: CPU por instancia EC2 (rating-api)"
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
            "Name=tag:Name,Values=cluster-controller,cluster-worker" \
  --region "$REGION" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
  aws cloudwatch put-metric-alarm \
    --alarm-name "videoclub-cpu-${INSTANCE_ID}" \
    --alarm-description "CPU del nodo ${INSTANCE_ID} supera el 70%" \
    --namespace "AWS/EC2" \
    --metric-name "CPUUtilization" \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 70 \
    --comparison-operator GreaterThanThreshold \
    --statistic Average \
    --treat-missing-data missing \
    --alarm-actions "$TOPIC_ARN" \
    --region "$REGION"
  echo "      Creada para instancia $INSTANCE_ID"
done

# --- rating-worker ---

# Alarma: Worker heartbeat (pods de rating-worker vivos)
echo "[4/4] Alarma: worker heartbeat (rating-worker)"
aws cloudwatch put-metric-alarm \
  --alarm-name "videoclub-worker-heartbeat" \
  --alarm-description "Worker pod dejó de enviar heartbeat — posible CrashLoopBackOff" \
  --namespace "Videoclub" \
  --metric-name "WorkerHeartbeat" \
  --period 30 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --statistic Sum \
  --treat-missing-data breaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

echo ""
echo "=== Alarmas creadas ==="
aws cloudwatch describe-alarms \
  --alarm-name-prefix "videoclub-" \
  --region "$REGION" \
  --query "MetricAlarms[].{Nombre:AlarmName,Estado:StateValue}" \
  --output table

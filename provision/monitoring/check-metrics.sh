echo "check metric values"
for METRIC in DBRequests DBErrors WorkerHeartbeat; do
  echo -n "$METRIC: "
  aws cloudwatch get-metric-statistics \
    --namespace Videoclub \
    --metric-name $METRIC \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Sum \
    --region us-east-1 \
    --query "Datapoints[0].Sum" \
    --output text
done



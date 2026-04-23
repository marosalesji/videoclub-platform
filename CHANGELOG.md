# Changelog

## v1.1
Telemetría básica con AWS CloudWatch + flags de crash para demos.

### rating-api
- `watchtower`: logs de Python van a CloudWatch Logs (`/videoclub/rating-api`)
- Métricas custom `DBRequests` y `DBErrors` (namespace `Videoclub`) en cada request a DB
- `FORCE_DB_CRASH=true`: simula caída de DB en `POST /rating` y `GET /ratings/{id}` — sube `DBErrors`, pod sigue vivo

### rating-worker
- `watchtower`: logs van a CloudWatch Logs (`/videoclub/rating-worker`)
- Métrica `WorkerHeartbeat` (namespace `Videoclub`) cada `HEARTBEAT_INTERVAL_SECONDS` (default 300s)
- `FORCE_CRITICAL_CRASH=true`: crashea antes del loop principal — pod entra en CrashLoopBackOff, heartbeat deja de llegar

## v1.0
App base sin telemetría. `rating-api` recibe ratings, valida contra RDS, encola en SQS. `rating-worker` consume SQS y persiste en RDS.

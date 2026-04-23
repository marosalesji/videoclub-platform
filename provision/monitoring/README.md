# Instrumentacion, metricas, logs y alertas

en la v1.1 de este proyecto se instrumentan las aplicaciones rating-api y
rating-worker para agregar envio de logs y metricas a AWS.

## Logs

utiliza la libreria watchtower  en python para conectar el logger estandar a
CloudWatch por medio de boto3..

## Metricas

Se agrega una metrica para saber el % de utilizacion del CPU de cada nodo en el
cluster de kubernetes.

Se agrega otra metrica para saber el error rate de los requests a la base de
datos en la aplicacion rating-api.

Se agrega un heartbeat a la aplicacion rating-worker

Para agregar metricas se utiliza boto3.put_metric_data

Dimension de una metrica: Normalmente se agrega una dimension, que es como una
etiqueta o identificador.

Por ejemplo Service=rating-api Pod=rating-api-abc123 Environment=staging

Para obtener métricas más detalladas (CPU por pod, memoria, disco) se necesita
un agente en cada nodo:

- **AWS**: CloudWatch Agent recolecta y envía métricas al namespace CloudWatch
- **Open source**: node-exporter expone métricas del nodo; Prometheus las
scrapea y Grafana las visualiza

Para recolección y envío de logs desde contenedores:
- **AWS**: CloudWatch Agent también puede leer archivos de log
- **Open source**: Fluentbit lee logs de los pods y los reenvía a cualquier
destino(CloudWatch, Elasticsearch, Loki, etc.)

## Alertas

Se agregan alertas con el script `create-alarms.sh` el cual suscribe un correo a
un topic de SNS para enviar las alertas.

Alertas:
- rating-worker no regresa heartbeat --> sugiere que hay un error en el pod
- el CPU Usage > 70%
- el % de error a requests a la base de datos es mayor a 30%

## Panel

TBD

## Simular crash

Simular crash critico y crash en la db al modificar estas variables de ambiente

```
kubectl set env deployment/rating-worker FORCE_CRITICAL_CRASH=true
kubectl set env deployment/rating-api FORCE_DB_CRASH=true
```

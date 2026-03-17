# videoclub-platform

Plataforma de demostración educativa para el curso de Desarrollo en la Nube.
Implementa un sistema de ratings de películas para una empresa ficticia llamada
**Videoclub**, desplegado en un cluster de Kubernetes sobre AWS.

## El sistema

**Videoclub Rating System** es una arquitectura producer/consumer:

- **rating-api** — API en FastAPI que recibe ratings de películas, valida que el
usuario y la película existen en RDS, y encola la solicitud en SQS
- **rating-worker** — worker en Python que consume mensajes de SQS y guarda los
ratings en RDS PostgreSQL

Ambos servicios corren como deployments en un cluster de k3s de 2 nodos sobre
EC2, aprovisionado con Terraform.

## Objetivos didácticos

Este repositorio está diseñado para una sesión de introducción a Kubernetes. El
objetivo es que los estudiantes entiendan los conceptos fundamentales de
orquestación de contenedores en un contexto real.

### Qué se aprende

| Concepto | Descripción |
|----------|-------------|
| Pod y Deployment | Unidad mínima de k8s y cómo se gestiona su ciclo de vida |
| Service y NodePort | Cómo se expone una app dentro y fuera del cluster |
| Nodo controller vs worker | Visible directamente en la consola de EC2 |
| Resource limits | CPU y memoria como ciudadanos de primera clase |
| Health checks | Liveness y readiness probes con el endpoint `/health` |
| Integración con AWS | Los pods interactúan con RDS, SQS y Secrets Manager |

## Despliegue

Sigue los READMEs en este orden:

### 1. Cluster k3s
```bash
cd provision/cluster
```

Sigue las instrucciones en
[`provision/cluster/README.md`](provision/cluster/README.md) para levantar el
cluster de 2 nodos con Terraform.

### 2. Recursos AWS del servicio de rating
```bash
cd provision/rating
```

Sigue las instrucciones en
[`provision/rating/README.md`](provision/rating/README.md) para crear RDS, SQS y
Secrets Manager con Terraform, inicializar la base de datos y desplegar la
aplicación en k8s.

### 3. Imágenes de Docker

Antes de hacer `kubectl apply`, las imágenes deben estar publicadas en Docker
Hub. Sigue las instrucciones en cada app:

- [`apps/rating-api/README.md`](apps/rating-api/README.md)
- [`apps/rating-worker/README.md`](apps/rating-worker/README.md)

> **Nota:** Los manifests en `provision/rating/manifests/` tienen dos valores
que debes actualizar manualmente antes de aplicarlos:
> - `<tu-usuario>` → tu usuario de Docker Hub
> - `<account-id>` → tu AWS Account ID (visible en la consola arriba a la
derecha)

## Verificar el despliegue
```bash
# Obtener la IP del controller
CONTROLLER_IP=$(cd provision/cluster && terraform output -raw controller_public_ip)
```

### Pods y servicios
```bash
kubectl get pods
kubectl get services
```

### API
```bash
# Health check
curl http://$CONTROLLER_IP:30080/health

# Enviar un rating
curl -X POST http://$CONTROLLER_IP:30080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 1, "rating": 5, "review": "Excelente película"}'

# Ver ratings de una película
curl http://$CONTROLLER_IP:30080/ratings/1
```

### Casos de error
```bash
# Movie no existe
curl -X POST http://$CONTROLLER_IP:30080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 99999, "user_id": 1, "rating": 4}'

# User no existe
curl -X POST http://$CONTROLLER_IP:30080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 99999, "rating": 4}'

# Rating fuera de rango
curl -X POST http://$CONTROLLER_IP:30080/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 1, "user_id": 1, "rating": 6}'
```

### Troubleshooting

Si algo no funciona como se espera, estos comandos ayudan a diagnosticar:
```bash
# Ver el estado de los pods
kubectl get pods

# Ver logs del API
kubectl logs -f deployment/rating-api

# Ver logs del worker
kubectl logs -f deployment/rating-worker

# Ver detalles de un pod (útil si está en CrashLoopBackOff o Pending)
kubectl describe pod <nombre-del-pod>

# Ver detalles del deployment
kubectl describe deployment rating-api
kubectl describe deployment rating-worker

# Ver eventos del cluster (errores de scheduling, imágenes no encontradas, etc.)
kubectl get events --sort-by='.lastTimestamp'

# Entrar al contenedor del API para debuggear
kubectl exec -it deployment/rating-api -- bash
```

### Base de datos

Para verificar directamente en RDS que los ratings se guardaron:
```bash
# Obtener la IP del controller
CONTROLLER_IP=$(cd provision/cluster && terraform output -raw controller_public_ip)

# Obtener credenciales de Secrets Manager desde tu laptop
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "videoclub/rds/credentials" \
  --region us-east-1 \
  --query SecretString \
  --output text)

RDSHOST=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
RDSUSER=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
RDSPASS=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
RDSDB=$(echo $SECRET   | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")
ssh -i provision/cluster/k3s.pem ubuntu@$CONTROLLER_IP \
  "PGPASSWORD=$RDSPASS psql --host=$RDSHOST --port=5432 --username=$RDSUSER \
  --dbname=$RDSDB --command='SELECT * FROM ratings ORDER BY created_at DESC LIMIT 10;'"
```

## Demo: Saturar el sistema

Vamos a simluar saturar el sistema que tenemos de ratings

```bash
./demo-ratings.sh # este solo envia dos requests
./demo-scale.sh # envia 100 requests en secuencia
./demo-scale-turbo.sh # envia 100 requests en el background

kubectl scale deployment rating-worker --replicas=5
```

Después de correr los scripts anteriores podemos ver como los pods están saturándose, en especial podemos
ir a la consola de AWS y ver que la queue `rating-requests` tiene varios mensajes esperando ser procesados.

Si queremos que el procesamiento escale, es necesario configurar el deployment de kubernetes con el siguiente
comando

```bash
kubectl scale deployment rating-worker --replicas=5
```

Kubernetes va a manejar el scaling creaton 4 pods más de rating-worker. Como estamos usando una SQS los workers
están desacoplados y pueden tomar mensajes de la queue de forma independiente, e insertarlos a la base de datos.

Cuando el pico de requests termine, nuestro sistema no necesita tener tantos pods corriendo y es posible reducir
el número de replicas.

```bash
kubectl scale deployment rating-worker --replicas=1
```
## Teardown

Es importante no olvidar hacer el teardown de este proyecto

```bash
CLUSTER_SG_ID=$(cd provision/cluster && terraform output -raw cluster_sg_id)
source provision/rating/.env

cd provision/rating && terraform destroy \
    -var="cluster_sg_id=${CLUSTER_SG_ID}" \
    -var="db_password=${RDSPASS}" \
    -auto-approve
cd ../..
cd provision/cluster && terraform destroy -auto-approve
cd ../..
rm provision/cluster/k3s.pem
rm ~/.kube/config
```

## Referencias

- [k3s](https://k3s.io/)
- [curso cloud-computing-gdl](https://github.com/marosalesji/cloud-computing-gdl)

# Recursos del videoclub

## Requisitos

- Cluster k3s desplegado (ver `../cluster/README.md`)
- Archivo `.env` con credenciales configurado
- AWS CLI configurado en tu laptop con credenciales válidas en `~/.aws/credentials`

## Configuración

Copia el archivo de ejemplo y edita tus valores:
```bash
cp .env.example .env
```

Las credenciales de `.env` deben coincidir con las que pasas a `terraform apply`.

## Levantar recursos AWS
```bash
# Obtener el security group del cluster
CLUSTER_SG_ID=$(cd ../cluster && terraform output -raw cluster_sg_id)

# Cargar variables de ambiente
source .env

# Inicializar y aplicar
terraform init
terraform apply \
  -var="cluster_sg_id=${CLUSTER_SG_ID}" \
  -var="db_password=${RDSPASS}" \
  -auto-approve
```

## Inicializar la base de datos

Las credenciales se obtienen desde tu laptop y se pasan al controller por SSH — el controller no necesita acceso a AWS.
```bash
# Obtener la IP del controller
CONTROLLER_IP=$(cd ../cluster && terraform output -raw controller_public_ip)

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

# Copiar los scripts al controller
scp -i ../cluster/k3s.pem \
  scripts/setup.sh \
  scripts/setup.sql \
  ubuntu@$CONTROLLER_IP:/home/ubuntu/

# Correr el setup pasando las credenciales como variables de entorno
ssh -i ../cluster/k3s.pem ubuntu@$CONTROLLER_IP \
  "RDSHOST=$RDSHOST RDSUSER=$RDSUSER RDSPASS=$RDSPASS RDSDB=$RDSDB bash setup.sh"
```

Esto crea las tablas, inserta los usuarios ficticios y carga el catálogo de películas de MovieLens.

## Desplegar la aplicación en k8s

Primero es necesario actualizar la variable SQS_QUEUE_URL con el recurso creado.

```bash
SQS_URL=$(terraform output -raw sqs_queue_url)

sed -i "s|https://sqs.*rating-requests|$SQS_URL|g" manifests/rating-api-deployment.yaml
sed -i "s|https://sqs.*rating-requests|$SQS_URL|g" manifests/rating-worker-deployment.yaml
```

Después corremos el comando `apply` para crear los recursos de k8s.
```bash
kubectl apply -f manifests/
kubectl get pods
kubectl get services
```

## Destruir recursos
```bash
terraform destroy \
  -var="cluster_sg_id=${CLUSTER_SG_ID}" \
  -var="db_password=${RDSPASS}" \
  -auto-approve
```

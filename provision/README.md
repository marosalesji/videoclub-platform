# Provision

Este directorio contiene la infraestructura necesaria para correr Videoclub en AWS.

## Estructura

- `cluster/` — cluster de k3s con dos nodos EC2 (controller y worker)
- `rating/` — recursos AWS para el servicio de ratings: RDS, SQS, Secrets Manager y manifests de kubernetes

## Antes de desplegar

- Ten Terraform instalado
- Configura AWS CLI con credenciales válida en `~/.aws/credentials`
- Edita los siguientes archivos con tus valores de usuario de Docker Hub y cuenta de AWS
  - rating-api-deployment.yaml
  - rating-worker-deployment.yaml

## Despliegue de cluster

Sigue los pasos en (cluster/README.md)[cluster/README.md]

## Recursos del videoclub

Sigue los pasos en (rating/README.md)[rating/README.md]

## Destruir recursos

Destruye en orden inverso al despliegue:

```bash
cd rating && terraform destroy -auto-approve
cd ..
cd cluster && terraform destroy -auto-approve
```

## Referencias
- [k3s](https://k3s.io/)

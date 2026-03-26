# Desplegar el cluster

Cluster de 2 nodos (1 controller + 1 worker) en AWS usando Terraform.
Este documento también cubre la instalación de k3s.

## Levantar el cluster
```bash
# Inicializar Terraform
terraform init

# Validar la configuración
terraform validate

# Revisar el plan de ejecución
terraform plan

# Crear la infraestructura
terraform apply -auto-approve

# Si es necesario forzar la recreación de las instancias
terraform apply -replace="aws_instance.controller" -replace="aws_instance.worker"
```

Extraer la llave privada y la IP del controller:
```bash
terraform output -raw ssh_private_key > k3s.pem
chmod 600 k3s.pem

CONTROLLER_IP=$(terraform output -raw controller_public_ip)
```

## Configurar `kubectl`

### Desde tu laptop

```bash
mkdir -p ~/.kube

# Copiar el kubeconfig desde el controller
ssh -i k3s.pem ubuntu@$CONTROLLER_IP \
  "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s/127.0.0.1/$CONTROLLER_IP/g" > ~/.kube/config

# Verificar que el cluster responde
kubectl get nodes
```

### Desde el controller

Conéctate por SSH y configura kubectl localmente:
```bash
ssh -i k3s.pem ubuntu@$CONTROLLER_IP
```

Ya dentro del controller:
```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config

kubectl get nodes
```

## Verificar la instalación del cluster

Si algo falla, estos comandos ayudan a diagnosticar el problema:
```bash
# Dentro del controller
sudo systemctl status k3s.service
sudo ss -lntp | grep 6443
sudo kubectl get nodes -o wide

# Dentro del worker
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 50 --no-pager

# Desde la laptop
kubectl get nodes
```

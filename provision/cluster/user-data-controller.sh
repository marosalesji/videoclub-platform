#!/bin/bash

set -eofx

echo "==== Iniciando user-data para Ubuntu ===="

if command -v sestatus >/dev/null 2>&1; then
  echo "SELinux detectado. Desactivándolo..."
  sudo setenforce 0 || true
  sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config || true
else
  echo "SELinux no está presente (normal en Ubuntu)"
fi

echo "Desactivando AppArmor..."
sudo systemctl stop apparmor || true
sudo systemctl disable apparmor || true

echo "Actualizando paquetes (apt)..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "Instalando dependencias..."
sudo apt-get install -y curl ca-certificates gnupg lsb-release

# --- Obtener IP pública y privada (EC2) ---
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "[DEBUG] public ip $PUBLIC_IP"
echo "[DEBUG] private ip $PRIVATE_IP"


echo "Instalando K3s Controller..."
curl -sfL https://get.k3s.io | \
INSTALL_K3S_EXEC="server --token ${cluster_token} --tls-san $PUBLIC_IP" \
bash

# --- Verificación ---
echo "K3s Controller instalado"
sleep 5
sudo systemctl status k3s --no-pager || true

# --- Configurar kubectl sin sudo para el usuario ubuntu ---
echo "Configurando kubectl para el usuario ubuntu..."

mkdir -p /home/ubuntu/.kube

sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# Exportar KUBECONFIG
if ! grep -q 'KUBECONFIG=.*/.kube/config' /home/ubuntu/.bashrc; then
  echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.bashrc
fi

echo "Configurando carga de .bashrc para el usuario ubuntu..."
UBUNTU_HOME="/home/ubuntu"
PROFILE_FILE="$UBUNTU_HOME/.profile"

touch "$PROFILE_FILE"
chown ubuntu:ubuntu "$PROFILE_FILE"

if ! grep -q "Load bashrc if present" "$PROFILE_FILE"; then
  cat << 'EOF' >> "$PROFILE_FILE"

# Load bashrc if present
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
fi

chown ubuntu:ubuntu "$PROFILE_FILE"

#!/bin/bash
set -eofx

echo "==== Iniciando user-data WORKER (Ubuntu 24.04) ===="

# --- AppArmor (opcional pero recomendado para evitar problemas con K3s) ---
echo "Desactivando AppArmor..."
sudo systemctl stop apparmor || true
sudo systemctl disable apparmor || true

# --- Actualizar sistema ---
echo "Actualizando sistema (apt)..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- Dependencias básicas ---
echo "Instalando dependencias..."
sudo apt-get install -y curl ca-certificates gnupg lsb-release

# --- Unirse al cluster K3s ---
echo "Instalando K3s Worker..."
curl -sfL https://get.k3s.io | \
K3S_URL="https://${controller_ip}:6443" \
K3S_TOKEN="${cluster_token}" \
bash

# --- Verificación ---
echo "K3s Worker instalado exitosamente"
sleep 5
sudo systemctl status k3s --no-pager || true

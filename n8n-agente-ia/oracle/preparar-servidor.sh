#!/usr/bin/env bash
# Prepara un servidor Ubuntu de Oracle Cloud para correr n8n con Caddy.
# Uso (en el servidor, dentro de esta carpeta):  sudo bash preparar-servidor.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta con sudo: sudo bash preparar-servidor.sh" >&2
  exit 1
fi
USUARIO="${SUDO_USER:-ubuntu}"

echo "==> Actualizando paquetes"
apt-get update -y
apt-get upgrade -y
apt-get install -y iptables-persistent netfilter-persistent curl git

# Las imágenes Ubuntu de Oracle traen reglas iptables que rechazan todo salvo SSH.
# Se abren 80 y 443 justo antes de la regla REJECT. Se hace ANTES de instalar
# Docker para no guardar en disco las reglas que Docker crea por su cuenta.
echo "==> Abriendo puertos 80 y 443 en iptables"
for puerto in 80 443; do
  if ! iptables -C INPUT -p tcp -m state --state NEW --dport "$puerto" -j ACCEPT 2>/dev/null; then
    pos=$(iptables -L INPUT --line-numbers | awk '$2=="REJECT"{print $1; exit}')
    if [[ -n "${pos}" ]]; then
      iptables -I INPUT "$pos" -p tcp -m state --state NEW --dport "$puerto" -j ACCEPT
    else
      iptables -A INPUT -p tcp -m state --state NEW --dport "$puerto" -j ACCEPT
    fi
  fi
done
netfilter-persistent save

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Instalando Docker"
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$USUARIO"
systemctl enable --now docker

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo
  echo "Se creó .env. Edítalo con tu subdominio (nano .env) y luego ejecuta:"
  echo "  docker compose up -d"
else
  echo "==> Levantando n8n + Caddy"
  docker compose up -d
fi

echo
echo "Listo. Cierra la sesión SSH y vuelve a entrar para usar docker sin sudo."

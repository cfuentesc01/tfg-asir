#!/bin/bash

set -e  # Detener el script en caso de error

# Redirigir la salida a un archivo de log para depuración
echo "Iniciando instalación de Docker..." | tee /var/log/docker_install.log

# Actualizar paquetes y permitir el uso de repositorios HTTPS
apt update && apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release | tee -a /var/log/docker_install.log

# Agregar la clave GPG oficial de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
chmod a+r /etc/apt/keyrings/docker.asc

# Agregar el repositorio de Docker
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
VERSION=$(lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$OS $VERSION stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Actualizar el índice de paquetes e instalar Docker
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin | tee -a /var/log/docker_install.log

# Verificar instalación
if ! command -v docker &> /dev/null; then
    echo "Docker no se instaló correctamente" | tee -a /var/log/docker_install.log
    exit 1
fi

# Instalar Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "v\K[0-9.]+' )
curl -L "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verificar instalación de Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose no se instaló correctamente" | tee -a /var/log/docker_install.log
    exit 1
fi

# Habilitar y arrancar Docker
systemctl enable --now docker | tee -a /var/log/docker_install.log

# Agregar el usuario actual al grupo docker (opcional, requiere reinicio de sesión)
USER_NAME=${SUDO_USER:-$USER}
usermod -aG docker "$USER_NAME"

# Mensaje de finalización
echo "Docker y Docker Compose se han instalado correctamente. Es recomendable cerrar sesión y volver a iniciarla para aplicar los cambios." | tee -a /var/log/docker_install.log

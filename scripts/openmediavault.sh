#!/bin/bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl apt-transport-https gnupg2

# Añadir la clave GPG del repositorio
sudo wget -O /etc/apt/trusted.gpg.d/openmediavault-archive-keyring.asc https://packages.openmediavault.org/public/archive.key

# Agregar el repositorio (OMV 7 "Sardaukar" para Debian 12)
echo "deb [arch=amd64] https://packages.openmediavault.org/public sandworm main" | sudo tee /etc/apt/sources.list.d/openmediavault.list

# Actualizar repositorios
sudo apt update

# Instalar paquetes principales
sudo apt install -y openmediavault-keyring openmediavault

# Poblar la base de datos de configuración
sudo omv-confdbadm populate

# Aplicar configuraciones iniciales
sudo omv-salt deploy run phpfpm nginx omv-engined
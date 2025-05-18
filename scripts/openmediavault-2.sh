#!/bin/bash

# Creación del raid
set -e

# Variables
RAID_DEVICE="/dev/md0"
DISK1="/dev/nvme1n1"
DISK2="/dev/nvme2n1"
MOUNT_POINT="/mnt/raid1"

echo "[+] Instalando mdadm..."
sudo apt-get update -y
sudo apt-get install -y mdadm --no-install-recommends

echo "[+] Creando RAID 1 con $DISK1 y $DISK2..."
sudo mdadm --create --verbose $RAID_DEVICE --level=1 --raid-devices=2 $DISK1 $DISK2 <<EOF
y
EOF

echo "[+] Esperando a que el array esté disponible..."
sleep 10

echo "[+] Guardando configuración en /etc/mdadm/mdadm.conf..."
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

echo "[+] Creando sistema de archivos ext4 en $RAID_DEVICE..."
sudo mkfs.ext4 -F $RAID_DEVICE

echo "[+] Creando punto de montaje en $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT

echo "[+] Montando RAID 1 en $MOUNT_POINT..."
sudo mount $RAID_DEVICE $MOUNT_POINT

echo "[+] Añadiendo entrada a /etc/fstab para montaje persistente..."
UUID=$(blkid -s UUID -o value $RAID_DEVICE)
echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab

echo "[+] RAID 1 montado correctamente en $MOUNT_POINT"

#cat /proc/mdstat

# Instalando OpenMediaVault
sudo wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash

# Reiniciando servicios
sudo systemctl restart openmediavault-engined
sudo systemctl restart php8.2-fpm
sudo systemctl restart nginx

# Recargar configuracion del servidor
sudo omv-salt stage run prepare
sudo omv-salt stage run deploy

# Monitorización
# Monitorización
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/node_exporter

# Instalación de Node Exporter
sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.3.0/node_exporter-1.3.0.linux-amd64.tar.gz -P /opt
sudo tar -xvf /opt/node_exporter-1.3.0.linux-amd64.tar.gz
sudo mv node_exporter-1.3.0.linux-amd64/ /opt/node_exporter

# Creación del servicio
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
[Unit]
Description=node_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
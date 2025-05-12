#!/bin/bash
set -e

# Variables
RAID_DEVICE="/dev/md0"
DISK1="/dev/xvdf"
DISK2="/dev/xvdg"
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
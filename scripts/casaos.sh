#!/bin/bash

# Actualizar sistema
sudo apt update && sudo apt upgrade -y
sudo apt install -y cron
sudo apt install mariadb-client

# Habilitar cron
sudo systemctl enable cron
sudo systemctl start cron

# Instalar CasaOS
sudo curl -fsSL https://get.casaos.io | sudo bash

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

sudo tee /home/admin/raid.sh > /dev/null << EOF
#!/bin/bash

set -e

# Variables
DISK1="/dev/nvme1n1"
DISK2="/dev/nvme2n1"
RAID_DEVICE="/dev/md0"
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
EOF

# Creación del script de backup de Gancio
sudo tee > /home/admin/rds-gancio.sh > /dev/null << EOF
#!/bin/bash
# Descripción: Backup de RDS MySQL para Gancio con retención de 30 días
# Autor: Carlos Fuentes Cobo
# Requisitos: AWS CLI v2, mysqldump, gzip

# Configuración (modifícalo si es necesario)
RDS_ENDPOINT="gancio-rds-mysql.cz44g2mci3yr.us-east-1.rds.amazonaws.com"
DB_NAME="gancio"
DB_USER="carlosfc"
DB_PASSWORD="1234567890asd."  # Alternativa: usar AWS Secrets Manager
BACKUP_DIR="/mnt/raid1/gancio_backup"  # Ruta montada en OpenMediaVault o similar
RETENTION_DAYS=30

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR"

# Nombre del archivo con timestamp
BACKUP_FILE="$BACKUP_DIR/gancio_db_$(date +%Y%m%d_%H%M%S).sql.gz"

# Ejecutar mysqldump con compresión directa
echo "[$(date +%F_%T)] Iniciando backup de $DB_NAME..."
mysqldump -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Verificar éxito del backup
if [ $? -eq 0 ]; then
    echo "[$(date +%F_%T)] Backup completado: $BACKUP_FILE"

    # Eliminar backups antiguos
    find "$BACKUP_DIR" -name "gancio_db_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "[$(date +%F_%T)] Limpieza de backups >$RETENTION_DAYS días"
else
    echo "[$(date +%F_%T)] ¡Error en el backup!" >&2
    exit 1
fi

EOF

# Creación del script de backup de Lemmy
sudo tee > /home/admin/rds-lemmy.sh > /dev/null << EOF
#!/bin/bash
# Descripción: Backup de RDS PostgreSQL para Lemmy con retención de 30 días
# Autor: Carlos Fuentes Cobo
# Requisitos: AWS CLI v2, pg_dump, gzip

# Configuración (¡modifícalo!)
RDS_ENDPOINT="lemmy.ct54twtvpwmw.us-east-1.rds.amazonaws.com"
DB_NAME="lemmy"
DB_USER="carlosfc"
BACKUP_DIR="/mnt/raid1/lemmy_backup"  # Ruta montada de OpenMediaVault
RETENTION_DAYS=30

# Obtener contraseña de AWS Secrets Manager (opcional)
# PASSWORD=$(aws secretsmanager get-secret-value --secret-id tu-secreto-rds --query SecretString --output text | jq -r .password)

# Alternativa: contraseña en variable de entorno (asegúrate de proteger este archivo)
export PGPASSWORD="1234567890asd."

# Crear directorio de backup si no existe
mkdir -p $BACKUP_DIR

# Nombre del archivo con timestamp
BACKUP_FILE="$BACKUP_DIR/lemmy_db_$(date +%Y%m%d_%H%M%S).sql.gz"

# Ejecutar pg_dump con compresión directa
echo "[$(date +%F_%T)] Iniciando backup de $DB_NAME..."
pg_dump -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME --no-password --format=plain | gzip > $BACKUP_FILE

# Verificar éxito del backup
if [ $? -eq 0 ]; then
    echo "[$(date +%F_%T)] Backup completado: $BACKUP_FILE"

    # Eliminar backups antiguos
    find $BACKUP_DIR -name "lemmy_db_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "[$(date +%F_%T)] Limpieza de backups >$RETENTION_DAYS días"
else
    echo "[$(date +%F_%T)] ¡Error en el backup!" >&2
    exit 1
fi

# Limpiar contraseña (seguridad)
unset PGPASSWORD
EOF

# Dando permisos
sudo chmod +x /home/admin/rds-*.sh

# Creando crontab
sudo bash -c 'cat > /tmp/mycron <<EOF
PATH=/usr/sbin:/usr/bin:/sbin:/bin

0 2 * * * /home/admin/rds-gancio.sh >> /home/admin/rds-gancio.log 2>&1
30 2 * * * /home/admin/rds-lemmy.sh >> /home/admin/rds-lemmy.log 2>&1
EOF
crontab /tmp/mycron
rm /tmp/mycron'
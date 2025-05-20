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

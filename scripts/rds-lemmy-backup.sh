#!/bin/bash
# Descripción: Backup de RDS PostgreSQL para Lemmy con retención de 30 días
# Autor: Carlos Fuentes Cobo
# Requisitos: AWS CLI v2, pg_dump, gzip

# Configuración (¡modifícalo!)
RDS_ENDPOINT="lemmy.ct54twtvpwmw.us-east-1.rds.amazonaws.com"
DB_NAME="lemmy"
DB_USER="carlosfc"
BACKUP_DIR="/mnt/lemmy_backup"  # Ruta montada de OpenMediaVault
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
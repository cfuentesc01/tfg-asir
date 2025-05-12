#!/bin/bash

# Variable RDS
DB_HOST=$(terraform output -raw rds_postgres_lemmy_host)

# Instalando dependencias
sudo apt update
sudo apt install -y wget ca-certificates pkg-config
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update -y
sudo apt install libssl-dev libpq-dev postgresql-client -y
# Instalar Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo tee /etc/apt/trusted.gpg.d/yarn.asc
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt update
sudo apt install yarn -y
sudo apt install -y postgresql-client

# Ejecutar comandos en PostgreSQL
PGPASSWORD="1234567890asd." psql -h "$DB_HOST" -U carlosfc -d postgres <<EOF
CREATE USER lemmy WITH PASSWORD '1234567890asd.';
CREATE DATABASE lemmy WITH OWNER lemmy;
GRANT ALL PRIVILEGES ON DATABASE lemmy TO lemmy;
EOF

# Instalando Rust
sudo apt install protobuf-compiler gcc -y

# Instalando ImageMagick
sudo apt install -y ffmpeg exiftool libgexiv2-dev --no-install-recommends 
wget https://download.imagemagick.org/ImageMagick/download/binaries/magick
sha256sum magick
sudo mv magick /usr/bin/
sudo chmod 755 /usr/bin/magick

sudo apt install rustup -y
sudo apt install cargo -y 
sudo apt install -y build-essential libpq-dev

# Lemmy backend
sudo useradd -m -d /opt/lemmy lemmy
git clone https://github.com/LemmyNet/lemmy.git lemmy
cd lemmy
git checkout 0.18.5
git submodule init
git submodule update
cargo build --release

# Deployment
sudo mkdir /opt/lemmy
sudo mkdir /opt/lemmy/lemmy-server
sudo mkdir /opt/lemmy/pictrs
sudo mkdir /opt/lemmy/pictrs/files
sudo mkdir /opt/lemmy/pictrs/sled-repo
sudo mkdir /opt/lemmy/pictrs/old
sudo chown -R lemmy:lemmy /opt/lemmy

sudo cp target/release/lemmy_server /opt/lemmy/lemmy-server/lemmy_server

# Configuration

# Ruta del archivo de configuración
LEMMY_FILE="/opt/lemmy/lemmy-server/lemmy.hjson"

sudo tee $LEMMY_FILE > /dev/null << EOF
database: {
  user: "lemmy"
  password: "1234567890asd."
  host: "$DB_HOST"
  port: 5432
  database: "lemmy"
  pool_size: 5
  sslmode: "require"
}

hostname: "lemmy-tfg.duckdns.org"
bind: "0.0.0.0"
tls_enabled: false
jwt_secret: "aROu1xO5+7Ew48vCxLGB3ZqGVt3yHa+DHXIIAIL9iNI="
EOF

sudo chown -R lemmy:lemmy /opt/lemmy/

SERVICE_FILE="/etc/systemd/system/lemmy.service"

sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Lemmy Server
After=network.target

[Service]
User=lemmy
ExecStart=/opt/lemmy/lemmy-server/lemmy_server
Environment=LEMMY_CONFIG_LOCATION=/opt/lemmy/lemmy-server/lemmy.hjson
Environment=PICTRS_ADDR=127.0.0.1:8080
Environment=RUST_LOG="info"
Environment=LEMMY_DATABASE_URL=postgres://lemmy:1234567890asd.@$DB_HOST:5432/lemmy?sslmode=require
Restart=on-failure
WorkingDirectory=/opt/lemmy

# Hardening
ProtectSystem=yes
PrivateTmp=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lemmy
sudo systemctl start lemmy

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart lemmy

# LEMMY - UI
# Instalando NodeJS
# nodejs
sudo apt install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt update
sudo apt install nodejs

# pnpm
sudo npm i -g pnpm
cd /opt/lemmy
sudo -u lemmy bash
cd /opt/lemmy
git clone https://github.com/LemmyNet/lemmy-ui.git --recursive
git checkout 0.18.5
yarn add webpack webpack-cli --dev
yarn install
yarn build:prod
exit

SERVICE_FILE_2="/etc/systemd/system/lemmy-ui.service"

sudo tee $SERVICE_FILE_2 > /dev/null << EOF
[Unit]
Description=Lemmy UI
After=lemmy.service
Before=nginx.service

[Service]
User=lemmy
WorkingDirectory=/opt/lemmy/lemmy-ui
ExecStart=/usr/bin/node dist/js/server.js
Environment=LEMMY_UI_LEMMY_INTERNAL_HOST=localhost:8536
Environment=LEMMY_UI_LEMMY_EXTERNAL_HOST=lemmy-tfg.duckdns.org
Environment=LEMMY_UI_HTTPS=true
Restart=on-failure

# Hardening
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload
sudo systemctl enable lemmy-ui
sudo systemctl start lemmy-ui

sudo tee /home/ubuntu/rds-lemmy-backup.sh > /dev/null << EOF
#!/bin/bash
# Descripción: Backup de RDS PostgreSQL para Lemmy con retención de 30 días
# Autor: Carlos Fuentes Cobo
# Requisitos: AWS CLI v2, pg_dump, gzip

# Configuración (¡modifícalo!)
RDS_ENDPOINT="$DB_HOST"
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

EOF

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


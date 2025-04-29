#!/bin/bash

# Instalando dependencias
sudo apt update
sudo apt install -y wget ca-certificates pkg-config
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update -y
sudo apt install libssl-dev libpq-dev postgresql-client -y
sudo npm install -g yarn

# Conectando el RDS de PostgreSQL
psql -h postgresql-2.ct54twtvpwmw.us-east-1.rds.amazonaws.com -U carlosfc -d postgres
CREATE USER lemmy WITH PASSWORD '1234567890asd.'
CREATE DATABASE lemmy;
ALTER DATABASE lemmy OWNER TO lemmy;

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
sudo adduser lemmy --system --disabled-login --no-create-home --group
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
  host: "lemmy.ct54twtvpwmw.us-east-1.rds.amazonaws.com"
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
Environment=LEMMY_DATABASE_URL=postgres://lemmy:1234567890asd.@lemmy.ct54twtvpwmw.us-east-1.rds.amazonaws.com:5432/lemmy?sslmode=require
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

sudo -u lemmy bash
cd /opt/lemmy
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



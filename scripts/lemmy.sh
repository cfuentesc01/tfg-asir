#!/bin/bash

# Instalando dependencias
sudo apt update
sudo apt install -y wget ca-certificates pkg-config
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update -y
sudo apt install libssl-dev libpq-dev postgresql -y

# Conectando el RDS de PostgreSQL
psql -h lemmy-rds-postgres.ct54twtvpwmw.us-east-1.rds.amazonaws.com -U carlosfc -d postgres
CREATE USER lemmy WITH PASSWORD '1234567890asd.'
CREATE DATABASE lemmy WITH OWNER lemmy;

# Instalando Rust
sudo apt install protobuf-compiler gcc -y

# Instalando ImageMagick
sudo apt install ffmpeg exiftool libgexiv2-dev --no-install-recommends
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


# LEMMY - UI

# Instalando NodeJS
sudo apt install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt update
sudo apt install nodejs -y

# pnpm
npm i -g pnpm



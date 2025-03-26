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

sudo apt install rustup
sudo apt install cargo

# Lemmy backend
sudo adduser lemmy --system --disabled-login --no-create-home --group
git clone https://github.com/LemmyNet/lemmy.git lemmy
cd lemmy
git checkout 0.18.5
git submodule init
git submodule update
cargo build --release

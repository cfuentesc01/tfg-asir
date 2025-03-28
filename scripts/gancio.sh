#!/bin/bash

# Instalar dependencias
sudo apt update
sudo apt install -y curl gcc g++ make wget libpq-dev

# Instalar Node.js y Yarn package manager
curl -sL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs
sudo npm install -g yarn

# Conexión con base de datos
sudo apt install -y mysql-client
sudo mysql -h gancio-rds-mysql.cz44g2mci3yr.us-east-1.rds.amazonaws.com -u carlosfc -p1234567890asd.
create database gancio;
create user gancio identified by '1234567890asd.';
grant all privileges on gancio.* to gancio;
#exit

# Crear usuario para ejecutar Gancio
sudo adduser --group --system --shell /bin/false --home /opt/gancio gancio

# Instalar Gancio
sudo yarn global add --network-timeout 1000000000 --silent https://gancio.org/latest.tgz

# Instalar systemd service y reload systemd
sudo wget http://gancio.org/gancio.service -O /etc/systemd/system/gancio.service
sudo systemctl daemon-reload
sudo systemctl enable gancio

# Arrancar el servicio de gancio (puerto 13120)
sudo systemctl start gancio

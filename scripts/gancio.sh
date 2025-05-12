#!/bin/bash

GANCIO_FILE="/opt/gancio/config.json"
POSTFIX1_FILE="/etc/postfix/main.cf"
POSTFIX2_FILE="/etc/postfix/sasl_passwd"
MAILNAME_FILE="/etc/mailname"
DB_HOST=$(terraform output -raw rds_mysql_gancio_host)

# Instalar dependencias
sudo apt update
sudo apt install -y curl gcc g++ make wget libpq-dev
sudo apt install -y mailutils

# Instalar Node.js y Yarn package manager
sudo curl -sL https://deb.nodesource.com/setup_20.x | bash -
sudo apt-get install -y nodejs
sudo npm install -g yarn

# Conexión con base de datos
sudo apt install -y mysql-client
sudo mysql -h ${DB_HOST} -u carlosfc -p1234567890asd. <<EOF
CREATE DATABASE IF NOT EXISTS gancio;
CREATE USER IF NOT EXISTS 'gancio'@'%' IDENTIFIED BY '1234567890asd.';
GRANT ALL PRIVILEGES ON gancio.* TO 'gancio'@'%';
FLUSH PRIVILEGES;
EOF

# Crear usuario para ejecutar Gancio
sudo adduser --group --system --shell /bin/false --home /opt/gancio gancio

# Instalar Gancio
sudo yarn global add --network-timeout 1000000000 --silent https://gancio.org/releases/gancio-v1.19.5.tgz

# Instalar systemd service y reload systemd
sudo wget http://gancio.org/gancio.service -O /etc/systemd/system/gancio.service
sudo systemctl daemon-reload
sudo systemctl enable gancio

# Arrancar el servicio de gancio
sudo systemctl daemon-reload
sudo systemctl start gancio
sudo systemctl daemon-reload

# Crear archivo mailname
sudo echo "gancio-tfg.duckdns.org" | tee $MAILNAME_FILE

# Configuración de Gancio con endpoint inyectado
#sudo tee $GANCIO_FILE > /dev/null << EOF
#{
#  "baseurl": "https://gancio-tfg.duckdns.org",
#  "hostname": "gancio-tfg.duckdns.org",
#  "server": {
#    "host": "0.0.0.0",
#    "port": 13120
#  },
#  "log_level": "debug",
#  "log_path": "/opt/gancio/logs",
#  "db": {
#    "dialect": "mariadb",
#    "storage": "",
#    "host": "${DB_HOST}",
#    "database": "gancio",
#    "username": "gancio",
#    "password": "1234567890asd.",
#    "logging": false,
#    "dialectOptions": {
#     "autoJsonMap": true
#    }
#  },
#  "user_locale": "/opt/gancio/user_locale",
#  "upload_path": "/opt/gancio/uploads",
#  "proxy": {
#    "protocol": "",
#    "hostname": "",
#    "host": "",
#    "port": "",
#    "auth": {
#      "username": "",
#      "password": ""
#    },
#    "headers": {}
#  }
#}
#EOF

# Instalar Postfix
sudo apt update
sudo apt install -y postfix mailutils procmail

# Preconfigurar Postfix
sudo echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
sudo echo "postfix postfix/mailname string localhost" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install -y postfix

# Crear archivo mailname
sudo echo "gancio-tfg.duckdns.org" | tee /etc/mailname

# Configuración de Postfix (main.cf)
sudo tee $POSTFIX1_FILE > /dev/null << EOF
smtpd_banner = \$myhostname ESMTP \$mail_name (Carlos Fuentes)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

myhostname = gancio-tfg.duckdns.org
mydomain = gancio-tfg.duckdns.org
myorigin = /etc/mailname

mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
relayhost = [smtp.gmail.com]:587
inet_interfaces = loopback-only
inet_protocols = all

mailbox_size_limit = 0
message_size_limit = 10485760
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination

smtpd_tls_cert_file = /etc/letsencrypt/live/gancio-tfg.duckdns.org/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/gancio-tfg.duckdns.org/privkey.pem
smtpd_tls_security_level = may
smtp_tls_security_level = encrypt
smtp_tls_CApath = /etc/ssl/certs
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_address_preference = ipv4

smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_mechanism_filter = plain
smtp_sasl_tls_security_options = noanonymous

smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination

alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
recipient_delimiter = +

debug_peer_level = 2
debug_peer_list = 127.0.0.1
mailbox_command = /usr/bin/procmail
EOF

# Configurar SASL auth
tee $POSTFIX2_FILE > /dev/null << EOF
[smtp.gmail.com]:587    pedrosusto1312@gmail.com:jrcx hhlr htzd gluf
EOF

sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd
sudo systemctl restart postfix
sudo systemctl daemon-reload

# Mensaje de comprobación
echo "Mensaje de prueba" | mail -s "Instalación correcta" pedrosusto1312@gmail.com

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
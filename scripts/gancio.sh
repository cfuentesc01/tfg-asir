#!/bin/bash

GANCIO_FILE="/opt/gancio/config.json"
POSTFIX1_FILE="/etc/postfix/main.cf"
POSTFIX2_FILE="/etc/postfix/sasl_passwd"

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

# Instalar PostFix
sudo apt update
sudo apt install postfix mailutils -y
sudo apt install procmail -y

# Implantar configuracion
# IMPLANTAR A MANO LOS CERTIFICADOS QUE HAY GUARDADOS
cat > $POSTFIX1_FILE << EOF
# Configuración básica
smtpd_banner = $myhostname ESMTP $mail_name (Carlos Fuentes)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

# Identificación del servidor
myhostname = gancio-tfg.duckdns.org
mydomain = gancio-tfg.duckdns.org
myorigin = /etc/mailname

# Destinos y redes
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
relayhost = [smtp.gmail.com]:587
inet_interfaces = loopback-only
inet_protocols = all

# Límites y políticas
mailbox_size_limit = 0
message_size_limit = 10485760
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination

# Configuración TLS/SSL
smtpd_tls_cert_file = /etc/ssl/certs/gancio-tfg.duckdns.org.crt
smtpd_tls_key_file = /etc/ssl/private/gancio-tfg.duckdns.org.key
smtpd_tls_security_level = may
smtp_tls_security_level = encrypt
smtp_tls_CApath = /etc/ssl/certs
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_address_preference = ipv4

# Autenticación SASL para Gmail
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_mechanism_filter = plain
smtp_sasl_tls_security_options = noanonymous

# Restricciones de relay
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination

# Aliases y entrega local
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
recipient_delimiter = +

# Registros y depuración
debug_peer_level = 2
debug_peer_list = 127.0.0.1
mailbox_command = /usr/bin/procmail
EOF


# Poner correo y contraseña
cat > $POSTFIX1_FILE << EOF
[smtp.gmail.com]:587    pedrosusto1312@gmail.com:jrcx hhlr htzd gluf

EOF
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd
sudo systemctl restart postfix

# Comprobar si funcionó la instalación
echo "Mensaje de prueba" | mail -s "Instalación correcta" pedrosusto1312@gmail.com
#!/bin/bash

# Dirección de correo para Certbot
EMAIL="carlos@gmail.com"
# Dominio para el certificado
DOMAIN="gancio-tfg.duckdns.org"
# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-enabled/gancio.conf"
LINK_FILE="/etc/nginx/sites-enabled/gancio.conf"

# Instalar dependencias
sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx-full python3-pip pipx -y
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
pip install certbot-dns-duckdns
pipx install certbot-dns-duckdns
sudo snap install --classic certbot
sudo snap install certbot-dns-duckdns
sudo snap set certbot trust-plugin-with-root=ok
sudo snap connect certbot:plugin certbot-dns-duckdns

# Ejecuta Certbot con los parámetros necesarios
sudo certbot certonly --nginx --email "$EMAIL" --agree-tos --no-eff-email --domain "$DOMAIN"

cat > $CONFIG_FILE << EOF
server {
  listen 80;
  listen [::]:80;
  server_name gancio-tfg.duckdns.org;

  keepalive_timeout    70;
  sendfile             on;
  client_max_body_size 80m;

  location / {
    try_files $uri @proxy;
  }

  location @proxy {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://127.0.0.1:13120;
  }
}
EOF

sudo ln -s $CONFIG_FILE $LINK_FILE

# Optimización
sudo mkdir -p /var/cache/nginx/gancio
sudo chown www-data: /var/cache/nginx/gancio

# Cache
#echo "proxy_cache_path /var/cache/nginx/gancio keys_zone=gancio_cache:1g max_size=80m inactive=1w;" | sudo tee -a /etc/nginx/nginx.conf

# Reiniciar Nginx
sudo systemctl daemon-reload
sudo systemctl reload nginx




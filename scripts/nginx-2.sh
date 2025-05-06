#!/bin/bash

# Dirección de correo para Certbot
EMAIL="carlos@gmail.com"
# Dominio para el certificado
DOMAIN="gancio-tfg.duckdns.org"
# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-available/gancio.conf"
LINK_FILE="/etc/nginx/sites-enabled/gancio.conf"

# Update and install necessary packages
apt-get update -y
apt-get install -y curl certbot

# Set up DuckDNS - Update the DuckDNS IP every 5 minutes
echo "Setting up DuckDNS update script..."
sudo mkdir -p /opt/duckdns
sudo cat <<DUCKDNS_SCRIPT > /opt/duckdns/duckdns.sh
#!/bin/bash
echo "Updating DuckDNS: lemmy-tfg.duckdns.org"
curl -k "https://www.duckdns.org/update?domains=gaancio-tfg.duckdns.org&token=ec9561c1-5778-489f-a589-7c4b12291f28&ip=" -o /opt/duckdns/duck.log
DUCKDNS_SCRIPT
chmod +x /opt/duckdns/duckdns.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns.sh >/dev/null 2>&1") | crontab -

# Update DuckDNS immediately to set the IP
echo "Updating DuckDNS IP..."
/opt/duckdns/duckdns.sh
sleep 30

# Detiene temporalmente cualquier proceso en el puerto 80 (como Apache o NGINX)
echo "Stopping any web server using port 80..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Obtain SSL certificate in standalone mode (non-interactive)
echo "Obtaining SSL certificate using certbot..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email carlos@gmail.com \
  -d "gancio-tfg.duckdns.org"

apt-get install nginx -y
apt install nginx-extras -y

sudo tee > $CONFIG_FILE > /dev/null << EOF
server {
  listen 80;
  listen [::]:80;
  server_name gancio-tfg.duckdns.org;

  # Redirección automática de HTTP a HTTPS
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name gancio-tfg.duckdns.org;

  ssl_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/gancio-tfg.duckdns.org/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/gancio-tfg.duckdns.org/chain.pem;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;

  keepalive_timeout    70;
  sendfile             on;
  client_max_body_size 80m;

  location / {
    try_files $uri @proxy;
  }

  location @proxy {
    proxy_pass http://10.208.4.70:13120;
    proxy_redirect / /;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Soporte para WebSockets
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
  }

  error_log /var/log/nginx/gancio_error.log;
  access_log /var/log/nginx/gancio_access.log;
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
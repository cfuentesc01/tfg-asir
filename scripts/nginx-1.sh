#!/bin/bash

# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-enabled/lemmy.conf"
CONFIG_FILE_2="/etc/nginx/nginx.conf"

# Update and install necessary packages
apt-get update -y
apt-get install -y curl certbot

# Set up DuckDNS - Update the DuckDNS IP every 5 minutes
echo "Setting up DuckDNS update script..."
sudo mkdir -p /opt/duckdns
sudo cat <<DUCKDNS_SCRIPT > /opt/duckdns/duckdns.sh
#!/bin/bash
echo "Updating DuckDNS: lemmy-tfg.duckdns.org"
curl -k "https://www.duckdns.org/update?domains=lemmy-tfg.duckdns.org&token=ec9561c1-5778-489f-a589-7c4b12291f28&ip=" -o /opt/duckdns/duck.log
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
  -d "lemmy-tfg.duckdns.org"

apt-get install nginx -y
apt install nginx-extras -y

sudo tee $CONFIG_FILE > /dev/null << EOF
limit_req_zone $binary_remote_addr zone=lemmy_ratelimit:10m rate=1r/s;

# Redirección HTTP -> HTTPS para Lemmy y OMV
server {
    listen 80;
    listen [::]:80;
    server_name lemmy-tfg.duckdns.org omv.lemmy-tfg.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# Configuración de Lemmy
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name lemmy-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/lemmy-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lemmy-tfg.duckdns.org/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    server_tokens off;
    add_header Strict-Transport-Security "max-age=63072000";
    add_header Referrer-Policy "same-origin";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header X-XSS-Protection "1; mode=block";

    client_max_body_size 20M;

    location / {
        proxy_pass http://10.208.3.50:1234;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_intercept_errors on;
        error_page 302 = @handle_redirect;
    }

    location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
        proxy_pass http://10.208.3.50:8536;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=lemmy_ratelimit burst=30 nodelay;
    }

    location @handle_redirect {
        proxy_pass http://10.208.3.50:1234;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Configuración de OpenMediaVault
server {
    listen 8443 ssl http2;
    listen [::]:8443 ssl http2;
    server_name lemmy-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/lemmy-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lemmy-tfg.duckdns.org/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    server_tokens off;
    add_header Strict-Transport-Security "max-age=63072000";
    add_header Referrer-Policy "same-origin";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header X-XSS-Protection "1; mode=block";

    location / {
        proxy_pass http://10.208.3.60:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=lemmy_ratelimit burst=30 nodelay;
    }
}

access_log /var/log/nginx/access.log combined;


EOF

sudo tee "$CONFIG_FILE_2" > /dev/null << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    limit_req_zone $binary_remote_addr zone=lemmy_ratelimit:10m rate=1r/s;

    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF


sudo systemctl reload nginx
sudo systemctl daemon-reload
sudo systemctl reload nginx

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
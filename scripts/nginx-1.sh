#!/bin/bash

# Dirección de correo para Certbot
EMAIL="carlos@gmail.com"
# Dominio para el certificado
DOMAIN="lemmy-tfg.duckdns.org"
# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-enabled/lemmy.conf"

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
#sudo certbot certonly --nginx --email "$EMAIL" --agree-tos --no-eff-email --domain "$DOMAIN"

sudo tee $CONFIG_FILE > /dev/null << EOF
limit_req_zone $binary_remote_addr zone=lemmy-tfg.duckdns.org_ratelimit:10m rate=1r/s;

server {
    listen 80;
    listen [::]:80;
    server_name lemmy-tfg.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name lemmy-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/lemmy-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lemmy-tfg.duckdns.org/privkey.pem;

    # TLS settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    server_tokens off;
    add_header Strict-Transport-Security "max-age=63072000";
    add_header Referrer-Policy "same-origin";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header X-XSS-Protection "1; mode=block";

    client_max_body_size 20M;

    # Frontend (Lemmy-UI)
    location / {
        proxy_pass http://10.208.3.50:1234;  # IP privada de Lemmy-UI
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;  # Critical para HTTPS

        # Manejar redirección 302 a /setup
        proxy_intercept_errors on;
        error_page 302 = @handle_redirect;
    }

    # Backend (Lemmy)
    location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
        proxy_pass http://10.208.3.50:8536;  # IP privada de Lemmy
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=lemmy-tfg.duckdns.org_ratelimit burst=30 nodelay;
    }

    # Manejar redirección a /setup
    location @handle_redirect {
        proxy_pass http://10.208.3.50:1234$uri;  # Forzar manejo de redirección
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

access_log /var/log/nginx/access.log combined;

EOF

sudo sed -i -e 's/{{domain}}/lemmy-tfg.duckdns.org/g' /etc/nginx/sites-enabled/lemmy.conf
sudo systemctl reload nginx
sudo systemctl daemon-reload


sudo certbot --nginx -d lemmy-tfg.duckdns.org -d omv.lemmy-tfg.duckdns.org
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

sudo certbot --nginx -d lemmy-tfg.duckdns.org -d omv.lemmy-tfg.duckdns.org

sudo tee $CONFIG_FILE > /dev/null << EOF
limit_req_zone $binary_remote_addr zone=lemmy-tfg.duckdns.org_ratelimit:10m rate=1r/s;

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

# Configuración de Lemmy (existente)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name lemmy-tfg.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/lemmy-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lemmy-tfg.duckdns.org/privkey.pem;

    # ... (Tus ajustes actuales de TLS y headers de seguridad)
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

    # Configuración existente de Lemmy
    location / {
        proxy_pass http://10.208.3.148:1234;
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
        proxy_pass http://10.208.3.148:8536;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=lemmy-tfg.duckdns.org_ratelimit burst=30 nodelay;
    }

    location @handle_redirect {
        proxy_pass http://10.208.3.148:1234$uri;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Configuración de OpenMediaVault (nuevo bloque server)
server {
    listen 8443 ssl http2;
    listen [::]:8443 ssl http2;
    server_name omv.lemmy-tfg.duckdns.org;  # Subdominio dedicado

    # Reutiliza el mismo certificado Wildcard de DuckDNS
    ssl_certificate /etc/letsencrypt/live/lemmy-tfg.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lemmy-tfg.duckdns.org/privkey.pem;

    # Ajustes idénticos a los de Lemmy para consistencia
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

    # Proxy hacia OMV (ajusta la IP privada según tu red)
location / {
    proxy_pass http://10.208.3.99:80;  # HTTP, no HTTPS
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # proxy_ssl_verify off;  # Ya no necesario, puedes quitar esta línea

    # Rate limiting
    limit_req zone=lemmy-tfg.duckdns.org_ratelimit burst=30 nodelay;

    }
}

access_log /var/log/nginx/access.log combined;

EOF

sudo sed -i -e 's/{{domain}}/lemmy-tfg.duckdns.org/g' /etc/nginx/sites-enabled/lemmy.conf
sudo systemctl reload nginx
sudo systemctl daemon-reload

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
limit_req_zone $binary_remote_addr zone={{domain}}_ratelimit:10m rate=1r/s;

server {
    listen 80;
    listen [::]:80;
    server_name {{domain}};
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
    server_name {{domain}};

    ssl_certificate /etc/letsencrypt/live/{{domain}}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{domain}}/privkey.pem;

    # Various TLS hardening settings
    # https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_session_timeout  10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets on;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Hide nginx version
    server_tokens off;

    # Enable compression for JS/CSS/HTML bundle, for improved client load times.
    # It might be nice to compress JSON, but leaving that out to protect against potential
    # compression+encryption information leak attacks like BREACH.
    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
    gzip_vary on;

    # Only connect to this site via HTTPS for the two years
    add_header Strict-Transport-Security "max-age=63072000";

    # Various content security headers
    add_header Referrer-Policy "same-origin";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header X-XSS-Protection "1; mode=block";

    # Upload limit for pictrs
    client_max_body_size 20M;

    # frontend
    location / {
      # The default ports:

      set $proxpass "http://0.0.0.0:1234";
      if ($http_accept ~ "^application/.*$") {
        set $proxpass "http://0.0.0.0:8536";
      }
      if ($request_method = POST) {
        set $proxpass "http://0.0.0.0:8536";
      }
      proxy_pass $proxpass;

      rewrite ^(.+)/+$ $1 permanent;

      # Send actual client IP upstream
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # backend
    location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
      proxy_pass http://0.0.0.0:8536;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";

      # Rate limit
      limit_req zone={{domain}}_ratelimit burst=30 nodelay;

      # Add IP forwarding headers
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

access_log /var/log/nginx/access.log combined;

EOF

sudo sed -i -e 's/{{domain}}/lemmy-tfg.duckdns.org/g' /etc/nginx/sites-enabled/lemmy.conf
sudo systemctl reload nginx
sudo systemctl daemon-reload

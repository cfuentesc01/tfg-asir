#!/bin/bash

# Archivo de configuracion
CONFIG_FILE="/etc/nginx/sites-enabled/lemmy.conf"

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

        limit_req zone=lemmy-tfg.duckdns.org_ratelimit burst=30 nodelay;
    }

    location @handle_redirect {
        proxy_pass http://10.208.3.50:1234$uri;
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
    proxy_pass http://10.208.3.60:80;  # HTTP, no HTTPS
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
# Gerado por servidor/configurar-servidor.sh
server {
    listen 80 default_server;
    root ${HTTP_DIR};
    autoindex on;

    location / {
        try_files $uri $uri/ =404;
    }

    # Avisos do phone_home do cloud-init (instalação concluída)
    location /phone-home/ {
        access_log /var/log/nginx/phone-home.log;
        return 200;
    }
}

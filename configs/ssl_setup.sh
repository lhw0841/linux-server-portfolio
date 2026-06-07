
#!/bin/bash
# SSL 자체 서명 인증서 생성 명령어
# 실제 운영 환경에서는 Let's Encrypt 사용 권장

sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=KR/ST=Busan/L=Busan/O=Portfolio/CN=localhost"

FROM nginx:alpine

RUN apk add --no-cache bash curl openssl gettext apache2-utils

COPY . /opt/tfw
WORKDIR /opt/tfw

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/srv/tfw/data", "/etc/tfw", "/etc/nginx/conf.d"]

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]

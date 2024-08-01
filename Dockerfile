FROM  php:8.1-fpm-alpine

LABEL maintainer="Rizal Fauzie <rizal@fauzie.id>"

ENV	COMPOSER_VERSION=2.7.7 \
	PHPREDIS_VERSION=5.3.7 \
	HOME=/magento \
	VIRTUAL_HOST="magento.local" \
	PHP_OPCACHE_ENABLE=On \
	PHP_MEMORY_LIMIT=768M \
	PHP_UPLOAD_SIZE=50M \
	PHP_MAX_EXECUTION=18000 \
	PHP_POST_MAX_SIZE=8M \
	PHP_TIMEZONE="Asia/Jakarta" \
	PHP_ERRORS=On \
	NGINX_ACCESS_LOG="/dev/stdout main" \
	SSH_PUBLIC_KEY=0 \
	ENABLE_IONCUBE=0 \
	ENABLE_CRON=0

COPY setup /setup

RUN apk add --no-cache --update linux-headers openssh bash redis supervisor \
	nginx libpng libjpeg-turbo icu-libs zlib git wget curl zip unzip bash \
	gettext freetype libxslt libintl libzip gmp libmcrypt \
	musl musl-utils musl-locales tzdata musl-locales-lang icu-data-full

RUN apk add --virtual .build-deps libxml2-dev libpng-dev libzip-dev libjpeg-turbo-dev libwebp-dev zlib-dev curl-dev \
    gmp-dev ncurses-dev gettext-dev icu-dev libxpm-dev libxslt-dev libmcrypt-dev freetype-dev make gcc g++ autoconf

RUN export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS" && \
	docker-php-source extract && \
	echo no | pecl install redis && \
	docker-php-ext-enable redis && \
	docker-php-ext-configure gd --with-jpeg --with-freetype && \
	docker-php-ext-configure intl --enable-intl && \
	docker-php-ext-configure opcache --enable-opcache && \
	docker-php-ext-install -j$(nproc) \
	bcmath bcmath ctype curl gd gettext gmp intl pcntl \
	mysqli opcache pdo_mysql soap xsl sockets zip

RUN mkdir -p /var/log/supervisor && \
	mkdir -p /var/log/cron && \
	mkdir -m 0644 -p /var/spool/cron/crontabs && \
	touch /var/log/cron/cron.log && \
	cp /setup/crontab.txt /var/crontab.txt

RUN apk del .build-deps && \
	docker-php-source delete && \
	rm -rf /tmp/* /var/cache/apk/* && \
	touch /var/log/supervisor.log

RUN cp /setup/php.ini /usr/local/etc/php/php.ini.tpl && \
	cp /setup/nginx.conf /etc/nginx/nginx.conf && \
	mkdir -p /etc/nginx/conf.d/ && cp /setup/magento.conf /etc/nginx/conf.d/magento.conf && \
	cp /setup/supervisor.conf /etc/supervisor.conf && \
	mv /setup/start.sh /start.sh && \
	chmod +x /start.sh

VOLUME /magento/website
WORKDIR /magento/website
ENTRYPOINT  /start.sh

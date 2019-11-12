FROM        php:7.1-fpm-alpine

ENV         COMPOSER_VERSION=1.9.1 \
            PHPREDIS_VERSION=4.2.0 \
            HOME=/magento

COPY        setup /setup

RUN         docker-php-source extract && \
            apk add --update --no-cache --virtual .build-dependencies \
            $PHPIZE_DEPS zlib-dev cyrus-sasl-dev autoconf gettext-dev pcre-dev \
            freetype-dev libjpeg-turbo-dev libpng-dev libmcrypt-dev g++ libtool make && \
            \
            apk add --no-cache wget htop nano zip unzip bash dcron git varnish \
            ca-certificates openssh tini libintl icu icu-dev libxml2-dev libltdl \
            gettext gmp-dev zlib freetype libjpeg-turbo libpng libmcrypt libxslt-dev pcre \
            nginx nginx-mod-http-headers-more nginx-mod-http-cache-purge supervisor && \
            \
            wget https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz -P /tmp && \
            tar -xzf /tmp/$PHPREDIS_VERSION.tar.gz -C /tmp && \
            mv /tmp/phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis && \
            \
            docker-php-ext-configure bcmath --enable-bcmath && \
            docker-php-ext-configure opcache --enable-opcache && \
            docker-php-ext-configure intl --enable-intl && \
            docker-php-ext-configure pdo_mysql --with-pdo-mysql && \
            docker-php-ext-configure soap --enable-soap && \
            docker-php-ext-configure mcrypt --enable-mcrypt && \
            docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
            \
            docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" \
            intl bcmath xsl xml zip soap mysqli pdo pdo_mysql gmp json opcache \
            dom redis iconv gd gettext exif mbstring simplexml xmlrpc mcrypt

RUN         mkdir -p /var/log/supervisor && \
            mkdir -p /var/log/cron && \
            mkdir -m 0644 -p /var/spool/cron/crontabs && \
            touch /var/log/cron/cron.log && \
            cp /setup/crontab.txt /var/crontab.txt && \
            \
            apk del .build-dependencies && \
            docker-php-source delete && \
            rm -rf /tmp/* /var/cache/apk/* && \
            touch /var/log/supervisor.log && \
            \
            wget https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar -O composer && \
            mv composer /usr/local/bin/composer && \
            chmod +x /usr/local/bin/composer && \
            composer self-update && \
            \
            cp /setup/php.ini /usr/local/etc/php/php.ini.tpl && \
            cp /setup/nginx.conf /etc/nginx/nginx.conf && \
            cp /setup/magento.conf /etc/nginx/conf.d/magento.conf && \
            cp /setup/supervisor.conf /etc/supervisor.conf && \
            cp /setup/default.vcl /etc/varnish/default.vcl && \
            cp /setup/magepath.sh /etc/profile.d/magepath.sh && \
            cp /setup/start.sh /start.sh && \
            echo "VARNISH_LISTEN_PORT=80" > /etc/varnish/varnish.params && \
            chmod +x /etc/profile.d/magepath.sh && \
            chmod +x /start.sh && \
            rm -rf /setup && \
            \
            addgroup -g 1000 magento && \
            adduser -h $HOME -u 1000 -s /bin/bash -D -G magento magento && \
            RANDPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo) && \
            echo "magento:${RANDPASS}" | chpasswd && \
            ssh-keygen -A

ENV         VIRTUAL_HOST="magento.local" \
            PATH="${PATH}:${HOME}/website/bin:${HOME}/.composer/vendor/bin" \
            SESSION_HANDLER="files" \
            SESSION_SAVE_PATH="/tmp/php/session" \
            SSH_PUBLIC_KEY=0 \
            PHP_OPCACHE_ENABLE=Off \
            PHP_MEMORY_LIMIT=768M \
            PHP_UPLOAD_SIZE=50M \
            PHP_MAX_EXECUTION=18000 \
            PHP_POST_MAX_SIZE=8M \
            PHP_TIMEZONE="Asia/Jakarta" \
            PHP_ERRORS=On \
            NGINX_ACCESS_LOG="/dev/stdout main" \
            ENABLE_VARNISH=0 \
            ENABLE_CRON=0

VOLUME      /magento/website
WORKDIR     /magento/website

CMD         ["/bin/bash", "/start.sh"]

#!/bin/bash

if [[ ! -f /etc/.started ]]
  then
    # Configure Composer
    if [[ ! -d "${HOME}/.composer" ]]
      then
        mkdir -p $HOME/.composer/vendor/bin
        chown -R magento:magento $HOME/.composer
    fi

    if [[ ! -d "${HOME}/website/bin" ]]
      then
         mkdir -p $HOME/website/bin
         chown -R magento:magento $HOME/website/bin
    fi

    # Configure PHP
    rm -rf /tmp/php
    mkdir -p /tmp/php/session
    chown -R magento:magento /tmp/php
    sed -ri 's/^user\s+.*/user = magento/' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's/^group\s+.*/group = magento/' /usr/local/etc/php-fpm.d/www.conf

    # Configure Nginx
    mkdir -p /var/run/nginx
    chown -R magento:magento /var/tmp/nginx
    chown -R magento:magento /run/nginx
    sed -i "s|@@SERVER_NAME@@|$SERVER_NAME|" /etc/nginx/nginx.conf
    sed -i "s|@@SERVER_ROOT@@|$HOME/website|" /etc/nginx/nginx.conf
    sed -i "s|@@NGINX_ACCESS_LOG@@|$NGINX_ACCESS_LOG|" /etc/nginx/nginx.conf

    if [[ -w "${HOME}/website/nginx.conf.sample" ]] && [[ ! -f "${HOME}/website/nginx.conf" ]]
     then
    	cp $HOME/website/nginx.conf.sample $HOME/website/nginx.conf
    fi

    # Configure SSH
    if [[ ! -f "${HOME}/.ssh/id_rsa" ]]
      then
        mkdir -p $HOME/.ssh
        chown -R magento:magento $HOME/.ssh
        chmod 750 $HOME/.ssh
    fi

    sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -ri 's/^#?RSAAuthentication\s+.*/RSAAuthentication yes/' /etc/ssh/sshd_config
    sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -ri 's/^#Port\s+.*/Port 2202/' /etc/ssh/sshd_config

    if [[ ! -f "${HOME}/.profile" ]]
      then
        echo "alias mage=\"php -dmemory_limit=-1 ${HOME}/website/bin/magento\"" > $HOME/.profile
    fi

    chown -R magento:magento $HOME
    # END Setup.
    touch /etc/.started
fi

if [[ -n "$SSH_PUBLIC_KEY" ]]
  then
    echo "$SSH_PUBLIC_KEY" > $HOME/.ssh/authorized_keys
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo "SSH Enabled with Public Key Authentication."
    echo " "
else
    echo "magento:m4g3nt0" | chpasswd
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "!!!! WARNING. SSH enabled with password authentication !!!!"
    echo "Username : magento"
    echo "Password : m4g3nt0"
    echo " "
fi

if [[ -f /var/spool/cron/crontabs/root ]]
 then
	rm /var/spool/cron/crontabs/root
fi

if [[ -f /usr/local/etc/php/php.ini.tpl ]]
 then
	rm -f /usr/local/etc/php/php.ini
    cp /usr/local/etc/php/php.ini.tpl /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_ERRORS@@|$PHP_ERRORS|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_UPLOAD_SIZE@@|$PHP_UPLOAD_SIZE|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_POST_MAX_SIZE@@|$PHP_POST_MAX_SIZE|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_MAX_EXECUTION@@|$PHP_MAX_EXECUTION|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_OPCACHE_ENABLE@@|$PHP_OPCACHE_ENABLE|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_TIMEZONE@@|$PHP_TIMEZONE|" /usr/local/etc/php/php.ini
    sed -i "s|@@PHP_MEMORY_LIMIT@@|$PHP_MEMORY_LIMIT|" /usr/local/etc/php/php.ini
    sed -i "s|@@SESSION_HANDLER@@|$SESSION_HANDLER|" /usr/local/etc/php/php.ini
    sed -i "s|@@SESSION_SAVE_PATH@@|$SESSION_SAVE_PATH|" /usr/local/etc/php/php.ini
fi

if [[ $ENABLE_CRON = '1' ]]
  then
    cp /var/crontab.txt /var/spool/cron/crontabs/magento
    chmod 0600 /var/spool/cron/crontabs/magento
    # RUN cron
    /usr/sbin/crond -f -L 8
elif [[ -f /var/spool/cron/crontabs/magento ]]
  then
	rm /var/spool/cron/crontabs/magento
fi

if [[ $ENABLE_VARNISH = '1' ]]
  then
    sed -ri 's/listen\s+.*/listen 127\.0\.0\.1:8080;/' /etc/nginx/nginx.conf
    # RUN varnish
    /usr/sbin/varnishd -F -f /etc/varnish/default.vcl
else
    sed -ri 's/listen\s+.*/listen 80;/' /etc/nginx/nginx.conf
fi

# END : run supervisor
/usr/bin/supervisord -c /etc/supervisor.conf

exec "$@"

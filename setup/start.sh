#!/bin/bash

set -m

if [[ ! -f /etc/.setuped ]]; then
	addgroup -g 1000 magento
	adduser -h $HOME -u 1000 -s /bin/bash -D -G magento magento
	RANDPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
	echo "magento:${RANDPASS}" | chpasswd

	# Configure Composer
	wget https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar -O composer
	mv composer /usr/local/bin/composer
	chmod +x /usr/local/bin/composer
	if [[ ! -d "${HOME}/.composer" ]]; then
		mkdir -p $HOME/.composer/vendor/bin
		chown -R magento:magento $HOME/.composer
	fi

	# Configure PHP
	rm -rf /tmp/php
	mkdir -p /tmp/php/session
	chown -R magento:magento /tmp/php
	sed -ri 's/^user\s+.*/user = magento/' /usr/local/etc/php-fpm.d/www.conf
	sed -ri 's/^group\s+.*/group = magento/' /usr/local/etc/php-fpm.d/www.conf

	if [[ -f /usr/local/etc/php/php.ini.tpl ]]; then
		rm -f /usr/local/etc/php/php.ini
		cp /usr/local/etc/php/php.ini.tpl /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_ERRORS@@|$PHP_ERRORS|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_UPLOAD_SIZE@@|$PHP_UPLOAD_SIZE|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_POST_MAX_SIZE@@|$PHP_POST_MAX_SIZE|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_MAX_EXECUTION@@|$PHP_MAX_EXECUTION|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_OPCACHE_ENABLE@@|$PHP_OPCACHE_ENABLE|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_TIMEZONE@@|$PHP_TIMEZONE|" /usr/local/etc/php/php.ini
		sed -i "s|@@PHP_MEMORY_LIMIT@@|$PHP_MEMORY_LIMIT|" /usr/local/etc/php/php.ini
	fi

	# Configure Nginx
	mkdir -p /var/run/nginx
	mkdir -p /var/tmp/nginx
	chown -R magento:magento /var/tmp/nginx
	chown -R magento:magento /var/run/nginx
	[ -d "/var/lib/nginx" ] && [ ! -L "/var/lib/nginx" ] && chown -R magento:magento /var/lib/nginx
	[ -d "/var/log/nginx" ] && [ ! -L "/var/log/nginx" ] && chown -R magento:magento /var/log/nginx
	[ -d "/var/cache/nginx" ] && [ ! -L "/var/cache/nginx" ] && chown -R magento:magento /var/cache/nginx
	sed -i "s|@@VIRTUAL_HOST@@|$VIRTUAL_HOST|" /etc/nginx/nginx.conf
	sed -i "s|@@SERVER_ROOT@@|$HOME/website|" /etc/nginx/nginx.conf
	sed -i "s|@@NGINX_ACCESS_LOG@@|$NGINX_ACCESS_LOG|" /etc/nginx/nginx.conf

	if [[ -w "${HOME}/website/nginx.conf.sample" ]] && [[ ! -f "${HOME}/website/nginx.conf" ]]; then
		cp $HOME/website/nginx.conf.sample $HOME/website/nginx.conf
	fi

	# Configure SSH
	ssh-keygen -A
	if [[ ! -f "${HOME}/.ssh/id_rsa" ]]; then
		mkdir -p $HOME/.ssh
		chown -R magento:magento $HOME/.ssh
		chmod 750 $HOME/.ssh
	fi

	sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
	sed -ri 's/^#?RSAAuthentication\s+.*/RSAAuthentication yes/' /etc/ssh/sshd_config
	sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
	sed -ri 's/^#Port\s+.*/Port 2202/' /etc/ssh/sshd_config

	if [[ $SSH_PUBLIC_KEY != '0' ]]; then
		echo "$SSH_PUBLIC_KEY" > $HOME/.ssh/authorized_keys
		sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
		echo "SSH Enabled with Public Key Authentication."
		echo " "
	else
		sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
		echo "!!!! WARNING. SSH enabled with password authentication !!!!"
		echo "Username : magento"
		echo "Password : ${RANDPASS}"
		echo " "
	fi

	# Configure Cron
	if [[ -f /var/spool/cron/crontabs/root ]]; then
		rm /var/spool/cron/crontabs/root
	fi
	if [[ $ENABLE_CRON != '0' ]]; then
		cp /var/crontab.txt /var/spool/cron/crontabs/magento
		chmod 0600 /var/spool/cron/crontabs/magento
		cat >> /etc/supervisor.conf <<- CRONCFG

		[program:crond]
		command = /usr/sbin/crond -f
		autostart = true
		autorestart = true
		startretries = 1
		priority = 20
		CRONCFG
	elif [[ -f /var/spool/cron/crontabs/magento ]]; then
		rm /var/spool/cron/crontabs/magento
	fi

	# Configure Ioncube
	if [[ $ENABLE_IONCUBE != '0' ]]; then
		PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');")
		cp /setup/ioncube.so $PHP_EXT_DIR
		echo 'zend_extension=ioncube.so' > $PHP_INI_DIR/conf.d/00-ioncube.ini
	fi

	if [[ ! -d "${HOME}/website/bin" ]]; then
		echo "=========================================================="
		echo " No mounted Magento directory on: /magento/website"
		echo " Installing latest Magento 2.4 ......"
		echo "=========================================================="
		mkdir -p /magento/website
		rm -rf /magento/website/*
		su - magento -c "/usr/local/bin/php /usr/local/bin/composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition /magento/website"
		echo " "
	fi

	cp /setup/magelist.txt $HOME/.magelist
	chown magento:magento $HOME/.magelist
	mv /setup/bashrc.txt $HOME/.bashrc
	echo ". ~/.bashrc" > $HOME/.profile
	chown magento:magento $HOME/.bashrc
	chown magento:magento $HOME/.profile
	# END Setup.
	touch /etc/.setuped
	rm -rf /setup
fi

# END : run supervisor
/usr/bin/supervisord -n -c /etc/supervisor.conf

exec "$@"

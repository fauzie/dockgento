#!/bin/bash

set -m

if [[ ! -d "${HOME}/website" ]]; then
	echo "=========================================================="
	echo " Please mount your Magento 2.x root directory to:"
	echo " /magento/website"
	echo "=========================================================="
	exit 1
fi

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

	# Configure Nginx
	mkdir -p /var/run/nginx
	chown -R magento:magento /var/tmp/nginx
	chown -R magento:magento /run/nginx
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

	if [[ -f /var/spool/cron/crontabs/root ]]; then
		rm /var/spool/cron/crontabs/root
	fi

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

	if [[ $ENABLE_CRON = '1' ]]; then
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

	mv /setup/bashrc.txt $HOME/.bashrc
	echo ". ~/.bashrc" > $HOME/.profile
	chown magento:magento $HOME/.bashrc
	chown magento:magento $HOME/.profile
	# END Setup.
	touch /etc/.setuped
	rm -rf /setup
fi

# END : run supervisor
/usr/bin/supervisord -c /etc/supervisor.conf

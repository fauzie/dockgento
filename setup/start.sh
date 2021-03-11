#!/bin/bash

set -m

if [[ ! -f /etc/.setuped ]]; then
	# Configure Composer
	if [[ ! -d "${HOME}/.composer" ]]; then
		mkdir -p $HOME/.composer/vendor/bin
		chown -R magento:magento $HOME/.composer
	fi

	if [[ ! -d "${HOME}/website/bin" ]]; then
		mkdir -p $HOME/website/bin
		chown -R magento:magento $HOME/website/bin
	fi

	# Configure PHP
	rm -rf /tmp/php
	mkdir -p /tmp/php/session
	chown -R magento:magento /tmp/php
	sed -ri 's/^user\s+.*/user = magento/' $PHP_INI_DIR-fpm.d/www.conf
	sed -ri 's/^group\s+.*/group = magento/' $PHP_INI_DIR-fpm.d/www.conf

	if [[ -f $PHP_INI_DIR/php.ini.tpl ]]; then
		rm -f $PHP_INI_DIR/php.ini
		cp $PHP_INI_DIR/php.ini.tpl $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_ERRORS@@|$PHP_ERRORS|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_UPLOAD_SIZE@@|$PHP_UPLOAD_SIZE|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_POST_MAX_SIZE@@|$PHP_POST_MAX_SIZE|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_MAX_EXECUTION@@|$PHP_MAX_EXECUTION|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_OPCACHE_ENABLE@@|$PHP_OPCACHE_ENABLE|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_TIMEZONE@@|$PHP_TIMEZONE|" $PHP_INI_DIR/php.ini
		sed -i "s|@@PHP_MEMORY_LIMIT@@|$PHP_MEMORY_LIMIT|" $PHP_INI_DIR/php.ini
		sed -i "s|@@SESSION_HANDLER@@|$SESSION_HANDLER|" $PHP_INI_DIR/php.ini
		sed -i "s|@@SESSION_SAVE_PATH@@|$SESSION_SAVE_PATH|" $PHP_INI_DIR/php.ini
	fi

	# Configure Nginx
	mkdir -p /var/run/nginx
	mkdir -p /var/tmp/nginx
	chown -R magento:magento /var/tmp/nginx
	chown -R magento:magento /var/run/nginx
	sed -i "s|@@VIRTUAL_HOST@@|$VIRTUAL_HOST|" /etc/nginx/nginx.conf
	sed -i "s|@@SERVER_ROOT@@|$HOME/website|" /etc/nginx/nginx.conf
	sed -i "s|@@NGINX_ACCESS_LOG@@|$NGINX_ACCESS_LOG|" /etc/nginx/nginx.conf

	if [[ -w "${HOME}/website/nginx.conf.sample" ]] && [[ ! -f "${HOME}/website/nginx.conf" ]]; then
		cp $HOME/website/nginx.conf.sample $HOME/website/nginx.conf
	fi

	# Configure SSH
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
		echo "magento:m4g3nt0" | chpasswd
		sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
		echo "!!!! WARNING. SSH enabled with password authentication !!!!"
		echo "Username : magento"
		echo "Password : m4g3nt0"
		echo " "
	fi

	if [[ ! -f "${HOME}/.profile" ]]; then
		echo "alias mage=\"php -dmemory_limit=-1 ${HOME}/website/bin/magento\"" > $HOME/.profile
	fi

	# Configure Ioncube
	if [[ $ENABLE_IONCUBE != '0' ]]; then
		PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');")
		cp /setup/ioncube.so $PHP_EXT_DIR
		echo 'zend_extension=ioncube.so' > $PHP_INI_DIR/conf.d/00-ioncube.ini
	fi

	if [[ -f /var/spool/cron/crontabs/root ]]; then
		rm /var/spool/cron/crontabs/root
	fi

	# Configure Cron
	if [[ $ENABLE_CRON != '0' ]]; then
		cp /var/crontab.txt /var/spool/cron/crontabs/magento
		chmod 0600 /var/spool/cron/crontabs/magento
		cat >> /etc/supervisord.conf <<- CRONCFG

		[program:crond]
		command = $(which crond) -f
		autostart = true
		autorestart = true
		startretries = 1
		priority = 3
		CRONCFG
	elif [[ -f /var/spool/cron/crontabs/magento ]]; then
		rm /var/spool/cron/crontabs/magento
	fi

	if [[ $ENABLE_VARNISH != '0' ]]; then
		sed -ri 's/listen\s+.*/listen 127\.0\.0\.1:8080;/' /etc/nginx/nginx.conf
		cat >> /etc/supervisord.conf <<- VARNSHCFG

		[program:varnish]
		command = /usr/sbin/varnishd -F -f /etc/varnish/default.vcl
		autostart = true
		autorestart = true
		startretries = 3
		priority = 4
		VARNSHCFG
	else
		sed -ri 's/listen\s+.*/listen 80;/' /etc/nginx/nginx.conf
	fi

	mv /setup/bashrc.txt $HOME/.bashrc
	echo ". ~/.bashrc" > $HOME/.profile
	chown -R magento:magento $HOME
	# END Setup.
	touch /etc/.setuped
	rm -rf /setup
fi

# END : run supervisor
/usr/bin/supervisord -c /etc/supervisor.conf

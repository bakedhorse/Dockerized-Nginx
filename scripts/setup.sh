#!/bin/bash

cd /app

# Refresh Updates
apt update
# Get add-apt-repository
apt install -y software-properties-common --no-install-recommends
# Get repos with latest nginx and php
add-apt-repository ppa:ondrej/nginx
add-apt-repository ppa:ondrej/php

# Update packages (again)
apt update

# Install nginx and php
apt install -y nginx php$PHP_VERSION php$PHP_VERSION-fpm --no-install-recommends

# Disable the default site file (it will be enabled on startup of container due to the default nginx-sites.txt file)
rm /etc/nginx/sites-enabled/default

# PHP Extensions
extension_file="/app/php-extensions.txt"
if [ -f "$extension_file" ]; then
	sed -i 's/\r$//' $extension_file
	sed -i -e '$a\' $extension_file

	sed_string="s/.*/php$PHP_VERSION-&/g"
	modules=$(sed "$sed_string" "$extension_file" | tr '\n' ' ')
	apt install --no-install-recommends --ignore-missing -y $modules
	if [ $? -ne 0 ]; then
        echo "Error occurred during apt installation. Exiting..."
        exit 1
    fi
else
    echo "Extensions file '$module_file' not found."
    exit 1
fi

# Additional packages
add_packages="/app/additional-packages.txt"
if [ -f "$add_packages" ]; then
    sed -i 's/\r$//' $add_packages
	sed -i -e '$a\'  $add_packages
	modules=$(<"$add_packages" tr '\n' ' ')
	apt install --no-install-recommends --ignore-missing -y $modules
	if [ $? -ne 0 ]; then
        echo "Error occurred during apt installation. Exiting..."
        exit 1
    fi
else
    echo "file '$module_file' not found."
    exit 1
fi

# Backup default of nginx
mkdir /app/default
cp -ar /etc/nginx/ /app/default/nginx
cp -ar /var/www/ /app/default/www
# Php backup
mkdir /app/default/php
cp -ar /etc/php/$PHP_VERSION /app/default/php/$PHP_VERSION

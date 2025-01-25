#!/bin/bash

# Exit script when SIGINT sent
function handle_sigint {
    echo "Received SIGINT. Exiting..."
    exit 1
}
trap 'handle_sigint' SIGINT

#### Check for files and directories needed to work
echo "==Checking for important directories/files"
# Check for nginx config
foldercheck=/etc/nginx
if [ -z "$(ls -A "$foldercheck")" ]; then
    echo "Empty nginx config, restoring defaults"

    # Copy defaults
    cp -ar /app/default/nginx /etc/
    cp -ar /app/default/www /var/
    # permissions
    chown www-data:www-data /var/www -R
    chown root:root /etc/nginx -R
fi
# Check for php fpm file for nginx
if ! [ -f "/etc/php_fpm" ]; then
  echo "PHP FPM include missing, restoring"
  cp -ar /app/scripts/php_fpm /etc/nginx/php_fpm
fi
# Check for php version folder
foldercheck=/etc/php/$PHP_VERSION
if [ -z "$(ls -A "$foldercheck")" ]; then
    echo "Empty php config, restoring defaults"
    mkdir /etc/php
    cp -ar /app/default/php/$PHP_VERSION /etc/php/$PHP_VERSION
fi
# Check for php-fpm socket
if ! [ -f "/run/php/php-fpm.sock " ]; then
    echo "PHP-FPM socket missing, restoring"
    ln -s /run/php/php$PHP_VERSION-fpm.sock /run/php/php-fpm.sock 
fi


# Check for www
foldercheck=/var/www
if [ -z "$(ls -A "$foldercheck")" ]; then
    echo "Empty www, restoring defaults"
    mkdir /var/www
    cp -ar /app/default/www /var/www
fi


# Make dir for php (idk bandaid solution fn)
mkdir -p /run/php/
# Fixing permissions of /var/www
chown www-data:www-data /var/www -R

echo
############### Update packages
echo "== Update packages"
# Update packages
export DEBIAN_FRONTEND="noninteractive"
if [[ "$APT_UPDATE_ON_START" == "1" ]]; then
	apt update
	apt upgrade -y
else
        echo "Package updates are disabled."
fi
echo

############# List out packages and other stuffs
# List php modules (and its packages)
echo "==Listing PHP Modules"
php -m
echo "==Listing PHP Module Packages"
apt list --installed | grep php$PHP_VERSION
echo

# Nginx module folder link
ln -s /usr/share/nginx/modules/ /etc/nginx/modules/

# Nginx sites
echo
echo "==Enabling nginx sites..."
site_file="/app/modules/nginx-sites.txt"
if [ -f "$site_file" ]; then
    sed -i 's/\r$//' $site_file
    sed -i -e '$a\' $site_file
    while IFS= read -r module; do
        if [ -z "$module" ]; then
            continue  # Skip to the next iteration
        fi
        if [[ $module == -* ]]; then
            module=${module#*-}
            echo "Disabling $module"
            rm /etc/nginx/sites-enabled/$module > /dev/null 2>&1
        else
            echo "Enabling $module"
			ln -s /etc/nginx/sites-available/$module /etc/nginx/sites-enabled/$module > /dev/null 2>&1
        fi
    done < "$site_file"
else
    echo "file '$site_file' not found. Enabling default site config"
    exit 1
fi

echo
############# Print version numbers
echo "==Nginx Version"
nginx -v
echo "==PHP Version"
php --version
echo ""

############ Start nginx and php
echo "==Starting software"
# FPM service
/etc/init.d/php$PHP_VERSION-fpm restart

# Nginx service
/etc/init.d/nginx start

# Keep service alive until SIGINT (better solution than a infinite loop)
#sleep infinity
while true
do
        chown www-data:www-data /var/www -R
        sleep 30
done

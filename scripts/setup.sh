#!/bin/bash

set -euo pipefail

cd /app

# Refresh Updates
apt update
# Get add-apt-repository
apt install -y software-properties-common --no-install-recommends

# Install nginx repo
apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring --no-install-recommends
install -d -m 700 /root/.gnupg
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg | grep -q '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62'
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null
cat <<'EOF' > /etc/apt/preferences.d/99nginx
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

# Install php repo
#add-apt-repository ppa:ondrej/php

# Update packages (again)
apt update

# Install nginx and php
apt install -y nginx php$PHP_VERSION php$PHP_VERSION-fpm --no-install-recommends

# Build headers-more as a dynamic module against the installed nginx.org package.
apt install -y build-essential git libpcre2-dev zlib1g-dev libssl-dev --no-install-recommends

nginx_version=$(nginx -v 2>&1 | sed -E 's|^nginx version: nginx/||')
configure_args=$(nginx -V 2>&1 | sed -n 's/^configure arguments: //p')
modules_path=$(printf '%s\n' "$configure_args" | grep -oE -- '--modules-path=[^ ]+' | cut -d= -f2)
modules_path=${modules_path:-/usr/lib/nginx/modules}

build_dir=$(mktemp -d)
curl -fSL "https://nginx.org/download/nginx-${nginx_version}.tar.gz" -o "$build_dir/nginx.tar.gz"
tar -xzf "$build_dir/nginx.tar.gz" -C "$build_dir"
git clone --depth 1 https://github.com/openresty/headers-more-nginx-module.git "$build_dir/headers-more-nginx-module"

cd "$build_dir/nginx-${nginx_version}"
eval ./configure "$configure_args" --with-compat --add-dynamic-module="$build_dir/headers-more-nginx-module"
make modules

mkdir -p "$modules_path"
cp objs/ngx_http_headers_more_filter_module.so "$modules_path/"

cd /app
rm -rf "$build_dir"
apt purge -y build-essential git libpcre2-dev zlib1g-dev libssl-dev
apt autoremove -y
apt clean

# Disable the default site file (it will be enabled on startup of container due to the default nginx-sites.txt file)
rm /etc/nginx/sites-enabled/default || true

# PHP Extensions
extension_file="/app/php-extensions.txt"
if [ -f "$extension_file" ]; then
	sed -i 's/\r$//' $extension_file
	sed -i -e '$a\' $extension_file

	sed_string="s/.*/php$PHP_VERSION-&/g"
	modules=$(sed -E '/^[[:space:]]*($|#)/d' "$extension_file" | sed "$sed_string" | tr '\n' ' ')
	if [ -n "$modules" ]; then
		if ! apt install --no-install-recommends --ignore-missing -y $modules; then
			echo "Error occurred during apt installation. Exiting..."
			exit 1
		fi
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
	modules=$(sed -E '/^[[:space:]]*($|#)/d' "$add_packages" | tr '\n' ' ')
	if [ -n "$modules" ]; then
		if ! apt install --no-install-recommends --ignore-missing -y $modules; then
			echo "Error occurred during apt installation. Exiting..."
			exit 1
		fi
	fi
else
    echo "file '$module_file' not found."
    exit 1
fi

# Backup default of nginx
mkdir -p /app/default/nginx /app/default/www
cp -ar /etc/nginx/. /app/default/nginx/
mkdir -p /var/www
cp -ar /var/www/. /app/default/www/
# Php backup
mkdir -p /app/default/php/$PHP_VERSION
cp -ar /etc/php/$PHP_VERSION/. /app/default/php/$PHP_VERSION/

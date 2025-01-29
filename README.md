# Dockerized-Nginx (Good-Enough-4-me)
This is a project made using docker Ubuntu 22.04, NGINX, and PHP.<br>
Meant to be a very barebones Docker for having a simple web server or proxy.

## Installation
```
git clone https://github.com/bakedhorse/Dockerized-Nginx
cd Dockerized-Nginx
docker compose build
docker compose up -d
```
You can change the name of the `Dockerized-Nginx` folder to anything.
<br>

## .env Configuration
The directory for the docker itself is set within `.env`. The default option is recommended, but is fine to change for unique setups.<br>
```
APP_DIR=./
```
<br>

The Dockerfile itself has two parameter configurations in `.env`. Changing these requires re-building the Dockerfile image.<br>
```
APT_UPDATE_ON_START=1
```
This parameter tells app.sh script will do `apt update` and `apt upgrade` on each start up. Would recommend having this disabled as this has a tendency to freeze randomly, along with this not saving any updated packages after a restart.
<br>
```
PHP_VERSION=8.3
```
This parameter tells what version of PHP to download and use. The Dockerfile uses the [ppa:ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php/) repo, and is recommended to check what version you can/cannot use.
<br>

## Storage of WWW, NGINX, and PHP folders
These folders are mounted in a folder `conf` wherever your `APP_DIR` is set to. (It should be in the same folder on it's default setting.)<br>
#### Any changes you want to make to NGINX, PHP, or your website files are done here.

## NGINX PHP-FPM Configuration
Due to NGINX not having a PHP-FPM file by default, you need to add one. The `scripts/` folder includes one and should've been copied into the `nginx` folder within `conf/`.<br>
Add this into your nginx config for setting up a site or proxy.
```
include /etc/nginx/php_fpm;
```
An example like
```
server {
    port 80;
    server_name _;
    root /var/www/html;
    index index.html;
    include /etc/nginx/php_fpm;
}
```

## Modules for NGINX
Due to the nature of NGINX's modules normally being baked in from the build process, there's a limited set of modules that can be used without building nginx from scratch. The modules that can be installed are called "dynamic modules".<br>
This Dockerfile uses [ppa:ondrej/nginx](https://launchpad.net/~ondrej/+archive/ubuntu/nginx/) repo which comes with some modules baked in, such as HTTP2. The Dockerfile also includes `headers-more-filter` from the same repo.<br>
Recommend going through the repo to find any dynamic module you want that's available and adding it in the `additional-packages.txt` in the `modules` folder. (*THIS WILL REQUIRE THE DOCKERFILE IMAGE TO BE RE-BUILT*)<br>
<br>
The modules installed from `apt` are stored in `/usr/share/nginx/modules/`. When you go into this directory, look for each module's file name and copy it. Don't forget it's extension which is usually `.so` Then add a line into the nginx.conf script at the top for each module. (Replace `<FILENAME>` with the file name, duh)
```
load_module modules/<FILENAME>;
```
Example being
```
load_module modules/ngx_http_headers_more_filter_module.so;
```

## Extensions for PHP
PHP is pulled from the [ppa:ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php/) repo. Recommended to find available extensions from here, or you can use the stock Ubuntu repos as well.<br>
Recommend to put any extensions you want into `php-extensions.txt` without `php-` at the beginning.<br>
(*THIS WILL REQUIRE THE DOCKERFILE IMAGE TO BE RE-BUILT*)

<br></br>
#### Will continue to work on this later. For now, it'll do.

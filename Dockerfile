FROM php:7.4-apache
LABEL maintainer="Jean Soares Fernandes <3454862+jeansf@users.noreply.github.com>"

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=America/Sao_Paulo

# Update sources
# Install "Git" – https://git-scm.com/
# Install Midnight Commander, Vim, Nano gnupg2
# Install "ImageMagick" executable – https://www.imagemagick.org/script/index.php
# Install "Composer" – https://getcomposer.org/
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update -y && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y git mc vim nano gnupg2 ca-certificates imagemagick \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /var/lib/apt/lists/* /tmp/*

RUN apt-get update -y && apt-get install --no-install-recommends -y zlib1g-dev libicu-dev g++ libcurl4-openssl-dev \
            libxslt-dev libexif-dev libwebp-dev libjpeg62-turbo-dev libpng-dev libxpm-dev \
            libfreetype6-dev libzip-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install curl intl xsl exif opcache zip gd sockets json iconv ctype bcmath \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Configure PHP
# Enable "mod_rewrite" – http://httpd.apache.org/docs/current/mod/mod_rewrite.html
# Enable "mod_headers" – http://httpd.apache.org/docs/current/mod/mod_headers.html
# Enable "mod_expires" – http://httpd.apache.org/docs/current/mod/mod_expires.html
# Remove default config apache2
# Create default with wildcard servername
COPY symfony.conf /etc/apache2/sites-available/symfony.conf
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/upload_max_filesize = .*/upload_max_filesize = 256M/' /usr/local/etc/php/php.ini \
    && sed -i 's/post_max_size = .*/post_max_size = 256M/' /usr/local/etc/php/php.ini \
    && sed -i 's/memory_limit = .*/memory_limit = 512M/' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.enable=1/opcache.enable=1/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=256/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=20000/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.enable_cli=0/opcache.enable_cli=1/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.save_comments=1/opcache.save_comments=1/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=0/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;realpath_cache_size = 4096k/realpath_cache_size=4096k/g' /usr/local/etc/php/php.ini \
    && sed -i 's/;realpath_cache_ttl = 120/realpath_cache_ttl=600/g' /usr/local/etc/php/php.ini \
    && sed -i "s:;date.timezone =:date.timezone = $TZ:g" /usr/local/etc/php/php.ini \
    && sed -i 's/#AddDefaultCharset UTF-8/AddDefaultCharset UTF-8/g'  /etc/apache2/conf-enabled/charset.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && a2enmod rewrite headers expires \
    && a2dissite 000-default \
    && a2ensite symfony \
    && echo "" > /etc/ssl/openssl.cnf

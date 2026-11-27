# EraMaster (Greenhill Academy) - Railway / Docker image
# PHP 8.3 + Apache (mod_php) + PostgreSQL client libs.  No build step: the app is plain PHP + static files.
FROM php:8.3-apache

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq-dev libzip-dev libonig-dev libxml2-dev libcurl4-openssl-dev \
 && docker-php-ext-install -j"$(nproc)" pdo_pgsql pgsql zip mbstring \
 && a2enmod rewrite headers remoteip \
 && rm -rf /var/lib/apt/lists/*
# (curl, simplexml, xmlreader, openssl are already built into the official image)

# Apache + PHP settings
COPY docker/apache-eramaster.conf /etc/apache2/conf-available/eramaster.conf
COPY docker/php-eramaster.ini     /usr/local/etc/php/conf.d/zz-eramaster.ini
RUN a2enconf eramaster \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Boot scripts live OUTSIDE the web root
COPY docker/entrypoint.sh   /opt/eramaster/entrypoint.sh
COPY docker/migrate.php     /opt/eramaster/migrate.php
COPY docker/reset-admin.php /opt/eramaster/reset-admin.php
COPY schema.sql             /opt/eramaster/schema.sql
RUN chmod +x /opt/eramaster/entrypoint.sh

# The application (see .dockerignore for what is left out)
COPY . /var/www/html/
RUN rm -rf /var/www/html/docker \
 && chown -R www-data:www-data /var/www/html

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/opt/eramaster/entrypoint.sh"]
CMD ["apache2-foreground"]

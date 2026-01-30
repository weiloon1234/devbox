# TODO: switch to official php:8.5-fpm when available/usable for your setup
FROM serversideup/php:8.5-fpm

USER root

# serversideup images typically include install-php-extensions
RUN if command -v install-php-extensions >/dev/null 2>&1; then \
      install-php-extensions bcmath pdo_mysql pdo_pgsql zip intl gd redis imagick; \
    else \
      echo "install-php-extensions not found in serversideup/php image"; exit 1; \
    fi

COPY php-dev.ini /usr/local/etc/php/conf.d/zz-dev.ini

WORKDIR /workspace
USER www-data
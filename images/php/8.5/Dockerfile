FROM php:8.5-fpm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl unzip zip \
    libzip-dev \
    libicu-dev \
    libpq-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libfreetype6-dev \
    imagemagick \
    libmagickwand-dev \
  && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" \
    bcmath \
    exif \
    gd \
    intl \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    sockets \
    zip

RUN pecl install redis imagick \
  && docker-php-ext-enable redis imagick

COPY php-dev.ini /usr/local/etc/php/conf.d/zz-dev.ini

WORKDIR /workspace
USER www-data

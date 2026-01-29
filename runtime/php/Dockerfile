ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm

# --------------------------------------------------
# System deps
# --------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    unzip \
    zip \
    libzip-dev \
    libpq-dev \
    libicu-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# PHP extensions (core)
# --------------------------------------------------
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) \
    bcmath \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    gd \
    imagick

# --------------------------------------------------
# Redis extension (PECL)
# --------------------------------------------------
RUN pecl install redis \
 && docker-php-ext-enable redis

# --------------------------------------------------
# Composer
# --------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /workspace
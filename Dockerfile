# Используем базовый образ с Apache, PHP и MariaDB
FROM php:8.2-apache

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    mariadb-client \
    && docker-php-ext-install mysqli \
    && apt-get clean

# Копируем файлы из директории files в контейнер
COPY files/wp-config.php /var/www/html/wordpress/wp-config.php

# Настройка конфигурации Apache
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf

# Включаем необходимые модули Apache
RUN a2enmod rewrite

# Перезапускаем Apache
RUN service apache2 restart

# Открываем порты
EXPOSE 80

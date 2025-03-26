#  Лабораторная работа №5  
## Запуск сайта в контейнере

---

##  Цель работы

Научиться запускать сайт WordPress в контейнере Docker с установленными Apache, PHP и MariaDB. Также — настроить конфигурации и запустить все сервисы с помощью Supervisor.

---
##  Задание 

Создать Dockerfile для сборки образа контейнера, который будет содержать веб-сайт на базе Apache HTTP Server + PHP (mod_php) + MariaDB. База данных MariaDB должна храниться в монтируемом томе. Сервер должен быть доступен по порту 8000.

Установить сайт WordPress. Проверить работоспособность сайта.

## 📁 Структура проекта

```
containers05/
├── Dockerfile
├── README.md
├── files/
│   ├── apache2/
│   ├── php/
│   ├── mariadb/
│   ├── supervisor/
│   │   └── supervisord.conf
│   └── wp-config.php
```


##  Шаги выполнения

### 1. Создание проекта

Создал папку `containers05` и необходимые подкаталоги, как показано выше.
```
mkdir containers05
cd containers05
mkdir files
mkdir files\apache2
mkdir files\php
mkdir files\mariadb
mkdir files\supervisor
echo. > Dockerfile
echo. > README.md
echo. > files\supervisor\supervisord.conf
echo. > files\wp-config.php
```
---

### 2. Базовый Dockerfile

Создал начальный `Dockerfile` на базе `debian:latest`:

```Dockerfile
FROM debian:latest

RUN apt-get update && \
    apt-get install -y apache2 php libapache2-mod-php php-mysql mariadb-server supervisor wget tar && \
    apt-get clean

VOLUME /var/lib/mysql
VOLUME /var/log
```

Собрал образ:

```bash
docker build -t apache2-php-mariadb .
```

---

### 3. Извлечение конфигураций

Создал временный контейнер:

```bash
docker run -d --name apache2-php-mariadb apache2-php-mariadb bash
```

Скопировал конфигурации из контейнера:

```bash
docker cp apache2-php-mariadb:/etc/apache2/sites-available/000-default.conf files/apache2/
docker cp apache2-php-mariadb:/etc/apache2/apache2.conf files/apache2/
docker cp apache2-php-mariadb:/etc/php/8.2/apache2/php.ini files/php/
docker cp apache2-php-mariadb:/etc/mysql/mariadb.conf.d/50-server.cnf files/mariadb/
```

Удалил контейнер:

```bash
docker stop apache2-php-mariadb
docker rm apache2-php-mariadb
```

---

### 4. Редактирование конфигураций

**Apache:**
- В `000-default.conf`:
  - Установлен `ServerName localhost`
  - Добавлен email в `ServerAdmin`
  - Добавлен `DirectoryIndex index.php index.html`

- В `apache2.conf`:  
  - Добавлена строка `ServerName localhost`

**PHP (`php.ini`):**
```ini
error_log = /var/log/php_errors.log
memory_limit = 128M
upload_max_filesize = 128M
post_max_size = 128M
max_execution_time = 120
```

**MariaDB (`50-server.cnf`):**
```ini
log_error = /var/log/mysql/error.log
```

---

### 5. Настройка Supervisor

Создал `files/supervisor/supervisord.conf`:

```ini
[supervisord]
nodaemon=true
logfile=/dev/null
user=root

[program:apache2]
command=/usr/sbin/apache2ctl -D FOREGROUND
autostart=true
autorestart=true
startretries=3
stderr_logfile=/proc/self/fd/2
user=root

[program:mariadb]
command=/usr/sbin/mariadbd --user=mysql
autostart=true
autorestart=true
startretries=3
stderr_logfile=/proc/self/fd/2
user=mysql
```

---

### 6. Установка WordPress и финальный Dockerfile

Добавил в Dockerfile:

```Dockerfile
# Установка WordPress
ADD https://wordpress.org/latest.tar.gz /tmp/
RUN tar -xzf /tmp/latest.tar.gz -C /var/www/html/ && rm /tmp/latest.tar.gz

# Копирование конфигураций
COPY files/apache2/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY files/apache2/apache2.conf /etc/apache2/apache2.conf
COPY files/php/php.ini /etc/php/8.2/apache2/php.ini
COPY files/mariadb/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY files/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/wp-config.php /var/www/html/wordpress/wp-config.php

# MariaDB: создание директории под сокет
RUN mkdir /var/run/mysqld && chown mysql:mysql /var/run/mysqld

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

---

### 7. Сборка и запуск

```bash
docker build -t apache2-php-mariadb .
docker run -d --name apache2-php-mariadb -p 8000:80 apache2-php-mariadb
```

📡 Перешёл в браузере по адресу:  
[http://localhost:8000/wordpress](http://localhost:8000/wordpress)

---

### 8. Создание базы данных

```bash
docker exec -it apache2-php-mariadb bash
mysql
```

```sql
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'wordpress';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

---

### 9. wp-config.php

Скопировал сгенерированный `wp-config.php` в `files/wp-config.php` и добавил его в Dockerfile.

---

## ❓ Ответы на вопросы

1. **Какие конфигурации были изменены?**  
   - `000-default.conf`  
   - `apache2.conf`  
   - `php.ini`  
   - `50-server.cnf`  
   - `wp-config.php`

2. **Зачем нужна директива `DirectoryIndex`?**  
   Указывает, какие файлы сервер должен загружать по умолчанию (например, `index.php`, `index.html`).

3. **Зачем нужен `wp-config.php`?**  
   Содержит параметры подключения к базе данных и настройки WordPress.

4. **Что делает `post_max_size` в `php.ini`?**  
   Ограничивает максимальный размер данных, отправляемых через POST-запрос.

5. **Недостатки текущего решения:**  
   - Все сервисы запускаются в одном контейнере (вместо использования `docker-compose`)  
   - Нет изоляции dev/prod  
   - Конфигурации "зашиты" в образ  
   - Отсутствует продвинутая безопасность

---

## ✅ Вывод

Я развернул сайт WordPress в Docker-контейнере, настроив Apache, PHP и MariaDB. Все сервисы работают стабильно под контролем Supervisor. Сайт доступен по адресу:

🔗 [http://localhost:8000/wordpress](http://localhost:8000/wordpress)

---

## ☁️ GitHub

```bash
git init
git add .
git commit -m "Lab 5: WordPress в контейнере"
git remote add origin https://github.com/мой_логин/containers05.git
git branch -M main
git push -u origin main
```

---

Если хочешь — я могу сгенерировать и красивый `README.md` файл прямо для вставки. Хочешь в `.md` формате?

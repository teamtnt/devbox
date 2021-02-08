# Setting up a development envioronment with docker

As a developer, you'll find yourself working on multiple projects. Therefore it's important that you have the correct development environment, which will allow you to easily switch between projects or add new ones.

We at TNT Studio follow some naming conventions, which, as you'll see will help us later.  For each of our projects, we create a top-level domain in the form of `someproject.test`. 

All of the projects are located in one root directory that we specify, for example, `/Users/nenad/devbox/www`

```
├── docker
├── project-a.test
    └── Dockerfile
├── someother-project.test
│   └── Dockerfile
└── project-c.test
    ├── Dockerfile
docker-compose.yml
```

In the above example, you'll see that we have a folder for each project, a folder called `docker` and a `docker-compose.yml` file.
The `docker-compose.yml` will hold the configuration that we need.

Before we go on, let's briefly explain what we're looking for in a development environment. 
Each of the projects should define its version of PHP, database and switching PHP versions should be simple.

To satisfy the database need for each project, we can run one docker container with a MariaDB server. The db server will have multiple databases, each for one project. In the `docker-compose.yml` file, this will look like:

```yaml
  #MariaDB Service
  devbox-db:
    image: mariadb:latest
    container_name: mariadb-devbox
    restart: unless-stopped
    tty: true
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_USER: root
      MYSQL_ROOT_PASSWORD: root
      SERVICE_TAGS: dev
      SERVICE_NAME: mariadb 
    volumes:
      - ./docker/mysql/data/:/var/lib/mysql/
      - ./docker/mysql/my.cnf:/etc/mysql/my.cnf
      - ./docker/mysql/seeds/:/docker-entrypoint-initdb.d
    networks:
      - devbox-network
```

When started, this will create a database server that also opens a port to the host so you can connect to the server with your favorite tool like TablePlus.
If you want your database to be seeded when created, add a dump file into the `docker/mysql/seeds/` folder. This will run only once and ensure that you get the data you need. If you need a custom configuration for you db server, you will put it in `docker/mysql/my.cnf`.
All of the database data will be stored in `docker/mysql/data/` which allows you to migrate the db to some other place easily.

Another thing that you might notice here is the `networks` directive. All of the services will run in a standalone network, so the containers
can communicate with each others. The network will be a simple brdige network and is defined as:

```yaml
#Docker Networks
networks:
  devbox-network:
    driver: bridge
```

Most of our projects use Redis, so we wan't to dedicate one container for this also:

```yaml
  devbox-redis:
      image: "redis:alpine"
      command: redis-server
      container_name: redis-devbox
      restart: unless-stopped
      ports:
       - "6379:6379"
      volumes:
        - ./docker/redis/redis-data:/var/lib/redis
        - ./docker/redis/redis.conf:/usr/local/etc/redis/redis.conf
      environment:
        - REDIS_REPLICATION_MODE=master
      networks:
        - devbox-network
```

In case you need some custom configuration, you can put it in `docker/redis/redis.conf`

Now, we come to the fun part, the PHP containers that host the application. Each of the projects should have a `Dockerfile`
that defines whatever is needed to run the application. A typical `Dockefile` would be.

```Dockerfile
FROM php:7.4-fpm

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Set working directory
WORKDIR /var/www

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    wget \
    zsh

RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install extensions
RUN docker-php-ext-install pdo_mysql exif pcntl
RUN docker-php-ext-install gd
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install opcache

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Add user for laravel application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Copy existing application directory contents
COPY . /var/www

# Copy existing application directory permissions
COPY --chown=www:www . /var/www

# Change current user to www
USER www

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]
```

This would be an instance with php-7.4-fpm, composer and some other basic linux tools. After the image is run, it's exposing port 9000
to handle PHP stuff the the webserver will throw at it.

The docker-compose configuration for this would be:


```yaml
  project-a.test:
    image: project-a.test:latest
    build: ./project-a.test
    container_name: project-a.test
    restart: unless-stopped
    tty: true
    environment:
      SERVICE_NAME: project-a.test
      SERVICE_TAGS: dev
    working_dir: /var/www/project-a.test
    volumes:
      - ./project-a.test/:/var/www/project-a.test/
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    networks:
      - devbox-network
```

We're almost done. In order to handle requests and route them to the correct instance, we'll create a nginx container.

```yaml
  #Nginx Service
  devbox-webserver:
    image: nginx:alpine
    container_name: webserver-devbox
    restart: unless-stopped
    tty: true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./:/var/www
      - ./docker/nginx/conf.d/:/etc/nginx/conf.d/
      - ./docker/cert/:/etc/ssl/certs/
    networks:
      - devbox-network
```

Nginx will look for a configuration file located in `docker/nginx/conf.d/`. The file might look as this:

```
server {
    server_name project-a.test;

    listen 443 ssl;
    listen 80;
    
    root /var/www/project-a.test/public;

    error_log  /var/log/nginx/project-a.test-error.log;
    access_log /var/log/nginx/project-a.test-access.log; 

    location ~ \.php$ {
        fastcgi_pass   project-a.test:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }

    location / {
        index       index.html index.htm index.php;
        try_files   $uri $uri/ /index.php?$query_string;
    }
}
```

One final step is now neccessary, to add the domain to `/etc/hosts`

```bash
127.0.0.1 project-a.test
```

Voila, there you have it. Now position yourself into `/Users/nenad/devbox/www` and run

```
$ docker-compose up -d
```

You should be able to run `project-a.test` in your browser.

Of course, adding this stuff manully each time might be cumbersome. So we created a helper script that will
do that for you in a single line.

`$ ./docker/bin/create-project.sh project-a.test`

# TNT Devbox

TNT Devbox is a starter kit for local development using docker containers.
To understand the principles behind `TNT Devbox` checkout the [guide](./guide.md).

## Creating a project

```bash
$ ./docker/bin/create-project.sh project-a.test
```

## Seeding a database

While you run your db container for the first time, you can create and seed a database.

Inside `./docker/mysql/seeds` put a database dump file. This will run only once
Note that your dump file needs to contain a `create database` statement, otherwise, the import won't work.

```mysql
CREATE DATABASE IF NOT EXISTS projectdb;
USE projectdb;
```

## Adding custom configuration file to nginx

Sometimes, your projects needs to have some rewrite rules or you migth add SSL certificates to your local development. 
All this can be setup in `./docker/nginx/conf.d/project-name.test`. In the bellow example, we're adding certificates:

```conf
server {
    server_name project-name.test;

    listen 443 ssl;
    listen 80;
    
    root /var/www/$http_host/public;

    ssl_certificate /etc/ssl/certs/project-name.test.crt; 
    ssl_certificate_key /etc/ssl/certs/project-name.test.key;

    error_log  /var/log/nginx/$http_host-error.log;
    access_log /var/log/nginx/$http_host-access.log; 

    location ~ \.php$ {
        fastcgi_pass   project-name.test:9000;
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

## Adding a custom php.ini

If you need some custom PHP settings you can do this by changing `./docker/php/local.ini`
Example:

```php
upload_max_filesize=128M
post_max_size=128M
```

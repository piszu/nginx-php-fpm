FROM alpine:3.8
LABEL Maintainer="Mariusz Pisz <git@mariuszpisz.pl>" \
      Description="Nginx 1.14 & PHP-FPM 7.2 based on Alpine Linux ready to go with Symfony 2.8"

# Install packages
RUN apk --no-cache add php7 php7-fpm php7-mysqli php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-ctype \
    php7-mbstring php7-gd nginx supervisor curl php-pdo php7-simplexml php7-xmlwriter \
    php7-tokenizer php7-redis php7-xsl php7-pdo_mysql php7-mysqlnd php7-pcntl \
    php7-iconv php7-posix acl
 
# git
RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh

# coposer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/custom.conf
COPY config/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Add application

RUN mkdir -p /var/www/
WORKDIR /var/www/
RUN git clone #here repo address
WORKDIR /var/www/reponape/
# copy parameters with db accesses
COPY src /var/www/reponape/app/config/

RUN SYMFONY_ENV=prod composer install --no-dev --optimize-autoloader

RUN rm -rf app/logs/*
RUN rm -rf app/cache/*
RUN HTTPDUSER=$(ps axo user,comm | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1)
RUN setfacl -dR -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX app/cache app/logs
RUN setfacl -R -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX app/cache app/logs
RUN php app/console cache:clear --env=prod --no-debug
RUN chmod a+w -R app/logs/
RUN chmod a+w -R app/cache/

# if needed
# RUN SYMFONY_ENV=prod php app/console doctrine:schema:update --force
# RUN php app/console assets:install --env=prod --no-debug

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=60s CMD curl --silent --fail http://127.0.0.1/

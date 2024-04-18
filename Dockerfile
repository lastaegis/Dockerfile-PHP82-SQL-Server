FROM alpine:3.19.0
LABEL author="Kementerian Keuangan - Direktorat Jenderal Kekayaan Negara"
LABEL maintener="ibnuauliana@kemenkeu.go.id"
LABEL version="1.0.0"
LABEL description="Instansi Service"

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV APP_ENV=prod
ENV APP_DEBUG=0

WORKDIR /application

# Add supervisord alpine
ADD docker/supervisord.conf /etc/supervisord.conf

# Install general utility
RUN apk update
RUN apk add bash
RUN apk add curl
RUN apk add supervisor

# Install NGINX and setup
RUN apk add nginx
COPY docker/nginx.conf /etc/nginx
COPY --chown=nginx:nginx . /application

WORKDIR /

# Install PHP82 and Create softlink to binary PHP
RUN apk add --no-cache php82 \
    php82-common \
    php82-fpm \
    php82-opcache \
    php82-cli \
    php82-curl \
    php82-openssl \
    php82-mbstring \
    php82-tokenizer \
    php82-fileinfo \
    php82-json \
    php82-xml \
    php82-pecl-redis \
    php82-phar \
    php82-pdo \
    php82-dev \
    php82-pear

# Install G++ Compiler and Make command
RUN apk add g++ \
    make \
    autoconf \
    unixodbc-dev

# Copy SQL Server APK to Dir
COPY docker/msodbcsql18_18.3.3.1-1_amd64.apk msodbcsql18_18.3.3.1-1_amd64.apk
COPY docker/mssql-tools18_18.3.1.1-1_amd64.apk mssql-tools18_18.3.1.1-1_amd64.apk


# Install the package(s)
RUN apk add --allow-untrusted msodbcsql18_18.3.3.1-1_amd64.apk
RUN apk add --allow-untrusted mssql-tools18_18.3.1.1-1_amd64.apk

# Install PDO SQLSRV
RUN pecl install sqlsrv \
    pdo_sqlsrv

RUN echo extension=pdo_sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/10_pdo_sqlsrv.ini
RUN echo extension=sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/20_sqlsrv.ini

# Install OpenSSL 1.0.2 and create softlink to binary
RUN wget https://www.openssl.org/source/openssl-1.0.2l.tar.gz
RUN tar -xzvf openssl-1.0.2l.tar.gz
RUN cd openssl-1.0.2l && ./config && make install
RUN ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl

# Config PHP
RUN ln -sf /usr/bin/php82 /usr/bin/php
RUN mkdir /var/run/php
RUN sed -i.bak 's@127.0.0.1:9000@/var/run/php/php82-fpm.sock@g' /etc/php82/php-fpm.d/www.conf
RUN sed -i.bak 's@nobody@nginx@g' /etc/php82/php-fpm.d/www.conf
RUN sed -i.bak 's@;listen.owner@listen.owner@g' /etc/php82/php-fpm.d/www.conf
RUN sed -i.bak 's@;listen.group@listen.group@g' /etc/php82/php-fpm.d/www.conf
RUN sed -i.bak 's@;listen.mode@listen.mode@g' /etc/php82/php-fpm.d/www.conf

# Cleansing and returning workdir to application
RUN rm msodbcsql18_18.3.3.1-1_amd64.apk
RUN rm mssql-tools18_18.3.1.1-1_amd64.apk
WORKDIR /application

# Expose port 80
EXPOSE 80

# Entry Point
# Equaly create tail -f /var/log/nginx/access.log
ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c","/etc/supervisord.conf"]

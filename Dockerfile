FROM php:7.4-apache
LABEL maintainer="Shihua <lidapeng@shihuacom.com>"

RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.tuna.tsinghua.edu.cn/' /etc/apt/sources.list && \
    sed -i 's/security-cdn.debian.org/mirrors.tuna.tsinghua.edu.cn/' /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libgmp-dev \
        libxml2-dev \
        zlib1g-dev \
        libncurses5-dev \
        libldb-dev \
        libldap2-dev \
        libicu-dev \
        libmemcached-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libsqlite3-dev \
        libzip-dev \
        libonig-dev \
        curl \
        msmtp \
        mariadb-client \
        git \
        subversion \
        supervisor \
        zip \
        unzip \
        cron \
        wget

ARG INSTALL_PYTHON2
RUN if [ "${INSTALL_PYTHON2}" = "true" ]; then \
    apt-get -y install python python-pip \
;fi

ARG INSTALL_PYGMENTS
RUN if [ "${INSTALL_PYGMENTS}" = "true" ]; then \
    pip install Pygments \
;fi

RUN rm -rf /var/lib/apt/lists/* && \
    rm -rf /etc/supervisor/* && \
    wget https://getcomposer.org/download/1.9.1/composer.phar -O /usr/local/bin/composer && \
    chmod a+rx /usr/local/bin/composer

COPY supervisord.conf /etc/supervisor/supervisord.conf

RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so && \
    ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
    docker-php-ext-install ldap && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --with-freetype && \
    docker-php-ext-install gd && \
    docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr && \
    docker-php-ext-install soap && \
    docker-php-ext-install intl && \
    docker-php-ext-install gmp && \
    docker-php-ext-install bcmath && \
    docker-php-ext-install zip && \
    docker-php-ext-install pcntl && \
    docker-php-ext-install sockets && \
#     pecl install mongodb && \
    pecl install memcached && \
    pecl install redis
#    pecl install xdebug

RUN pecl install apcu \
    && pecl install apcu_bc-1.0.3 \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini

ADD http://www.zlib.net/zlib-1.2.11.tar.gz /tmp/zlib.tar.gz
RUN tar zxpf /tmp/zlib.tar.gz -C /tmp && \
    cd /tmp/zlib-1.2.11 && \
    ./configure --prefix=/usr/local/zlib && \
    make && make install && \
    rm -Rf /tmp/zlib-1.2.11 && \
    rm /tmp/zlib.tar.gz

ADD https://blackfire.io/api/v1/releases/probe/php/linux/amd64/74 /tmp/blackfire-probe.tar.gz
RUN tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp && \
    mv /tmp/blackfire-*.so `php -r "echo ini_get('extension_dir');"`/blackfire.so && \
    rm /tmp/blackfire-probe.tar.gz

ENV LOCALTIME Asia/Shanghai
ENV HTTPD_CONF_DIR /etc/apache2/conf-enabled/
ENV HTTPD__DocumentRoot /var/www/html
ENV HTTPD__LogFormat '"%a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" common'

RUN rm $PHP_INI_DIR/conf.d/docker-php-ext* && \
    echo 'sendmail_path = /usr/bin/msmtp -t' >> $PHP_INI_DIR/conf.d/00-default.ini && \
    sed -i "s/DocumentRoot.*/DocumentRoot \${HTTPD__DocumentRoot}/"  /etc/apache2/apache2.conf && \
    echo 'ServerName ${HOSTNAME}' > $HTTPD_CONF_DIR/00-default.conf && \
    echo 'ServerSignature Off' > /etc/apache2/conf-enabled/z-security.conf && \
    echo 'ServerTokens Minimal' >> /etc/apache2/conf-enabled/z-security.conf && \
    touch /etc/msmtprc && chmod a+w -R $HTTPD_CONF_DIR/ /etc/apache2/mods-enabled $PHP_INI_DIR/ /etc/msmtprc && \
    rm /etc/apache2/sites-enabled/000-default.conf

COPY docker-entrypoint.sh /entrypoint.sh

RUN chmod a+rx /entrypoint.sh && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www

ENTRYPOINT ["/entrypoint.sh"]

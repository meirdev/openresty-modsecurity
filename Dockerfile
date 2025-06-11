ARG OPENRESTY_VERSION="1.27.1.2"

ARG MODSEC_VERSION="3.0.14"
ARG MODSEC_NGINX_VERSION="1.0.4"

ARG LMDB_VERSION="0.9.31"

FROM ubuntu:24.10

ARG OPENRESTY_VERSION
ARG MODSEC_VERSION
ARG MODSEC_NGINX_VERSION
ARG LMDB_VERSION
ARG CRS_RELEASE

RUN apt update -y; \
    apt install -y --no-install-recommends --no-install-suggests \
    build-essential \
    automake \
    cmake \
    curl \
    doxygen \
    g++ \
    git \
    gpg \
    jq \
    libcurl4-gnutls-dev \
    libfuzzy-dev \
    libmaxminddb-dev \
    liblua5.4-dev \
    libpcre3-dev \
    libpcre2-dev \
    libssl-dev \
    libtool \
    libxml2-dev \
    libyajl-dev \
    make \
    nano \
    patch \
    pkg-config \
    ruby \
    zlib1g-dev;

RUN set -eux; \
    git clone https://github.com/LMDB/lmdb --branch LMDB_$LMDB_VERSION --depth 1; \
    make -C lmdb/libraries/liblmdb install;

RUN set -eux; \
    git clone https://github.com/owasp-modsecurity/ModSecurity --branch v$MODSEC_VERSION --depth 1 --recursive; \
    cd ModSecurity/; \
    ./build.sh; \
    ./configure --with-yajl --with-ssdeep --with-lmdb --with-pcre2 --with-maxmind --enable-silent-rules; \
    make install

RUN set -eux; \
    git clone https://github.com/owasp-modsecurity/ModSecurity-nginx.git --branch v$MODSEC_NGINX_VERSION --depth 1; \
    curl -sSL https://openresty.org/download/openresty-$OPENRESTY_VERSION.tar.gz -o openresty-$OPENRESTY_VERSION.tar.gz; \
    tar -xvzf openresty-$OPENRESTY_VERSION.tar.gz; \
    cd openresty-$OPENRESTY_VERSION/; \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx; \
    gmake; \
    gmake install;

RUN set -eux; \
    mkdir /etc/modsecurity.d; \
    curl -sSL https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping -o /etc/modsecurity.d/unicode.mapping

COPY ./bin/download-latest-crs /usr/local/bin/download-latest-crs
RUN set -eux; \
    chmod +x /usr/local/bin/download-latest-crs; \
    /usr/local/bin/download-latest-crs;

COPY ./bin/download-latest-geolite /usr/local/bin/download-latest-geolite
RUN set -eux; \
    chmod +x /usr/local/bin/download-latest-geolite; \
    /usr/local/bin/download-latest-geolite;

COPY ./nginx /etc/nginx

RUN mkdir -p /var/log/nginx;

ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH
ENV PATH=/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:$PATH

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]

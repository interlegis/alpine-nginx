#!/usr/bin/env bash

SERVICE_USER=${SERVICE_USER:-"root"}
NGINX_MAIL_ENABLE=${NGINX_MAIL_ENABLE:-"false"}
NGINX_MAIL_PROTOCOLS=${NGINX_MAIL_PROTOCOLS:-"smtp-587 imap-143 pop3-110"}
NGINX_MAIL_AUTH_HTTP=${NGINX_MAIL_AUTH_HTTP:-"localhost"}
NGINX_MAIL_SSL_ENABLE=${NGINX_MAIL_SSL_ENABLE:-"false"}
NGINX_MAIL_SMTP_XCLIENT=${NGINX_MAIL_SMTP_XCLIENT:-"false"}
NGINX_MAIL_PROXY_ERRMSG=${NGINX_MAIL_PROXY_ERRMSG:-"false"}
NGINX_SSL_PATH=${NGINX_SSL_PATH:-"${SERVICE_HOME}/certs"}
NGINX_PHP_FPM_HOST=${NGINX_PHP_FPM_HOST:-""}
NGINX_PHP_FPM_PORT=${NGINX_PHP_FPM_PORT:-"9000"}

cat << EOF > ${SERVICE_HOME}/conf/nginx.conf
user  ${SERVICE_USER};
worker_processes  2;

error_log  ${SERVICE_HOME}/log/error.log warn;
pid        ${SERVICE_HOME}/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       ${SERVICE_HOME}/conf/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  ${SERVICE_HOME}/log/access.log  main;

    sendfile        off;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include ${SERVICE_HOME}/sites/*.conf;
}
EOF

if [ "X${NGINX_MAIL_ENABLE}" == "Xtrue" ]; then
  cat << EOF >> ${SERVICE_HOME}/conf/nginx.conf

mail {
    include ${SERVICE_HOME}/mailhosts/*.conf;
}
EOF
  MAILPORTSCFG=(${NGINX_MAIL_PROTOCOLS// / })

  if [ "X${NGINX_MAIL_SSL_ENABLE}" == "Xtrue" ]; then
    keyfiles=`ls -1 ${NGINX_SSL_PATH}/*.key`
    RC=`echo $?`
    keyfile=${keyfiles[0]}
    certfiles=`ls -1 ${NGINX_SSL_PATH}/*.crt ${NGINX_SSL_PATH}/*.pem 2>/dev/null`
    certfile=${certfiles[0]} 
    
    if [ $RC -eq 0 ]; then
      touch ${SERVICE_HOME}/mailhosts/ssl.conf
      cat << EOF >> ${SERVICE_HOME}/mailhosts/ssl.conf
  ssl_certificate ${certfile};
  ssl_certificate_key ${keyfile};
  ssl_session_timeout 5m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;
  ssl_prefer_server_ciphers   on;
EOF
    fi
  fi

  echo "Generating mailhost configuration templates..."

  for portcfg in ${MAILPORTSCFG[*]}; 
  do
    aport=(${portcfg//-/ })
    protocol=${aport[0]}
    port=${aport[1]}
    secmode=${aport[2]}
   
    sslconf=""
    if [ -f "${SERVICE_HOME}/mailhosts/ssl.conf" ]; then
      if [ "${secmode}" == "starttls" ]; then
        sslconf="starttls only;"
      elif [ "${secmode}" == "ssl" ]; then
        sslconf="ssl on;"
      fi
    fi

    xclient=""
    if [ "$protocol" == "smtp" ]; then
      if [ "X${NGINX_MAIL_SMTP_XCLIENT}" == "Xtrue" ]; then
        xclient="xclient on;"
      else 
        xclient="xclient off;"
      fi 
    fi

    proxy_errmsg=""
    if [ "X${NGINX_MAIL_PROXY_ERRMSG}" == "Xtrue" ]; then
      proxy_errmsg="proxy_pass_error_message on;"
    fi

    portpadded=$(printf "%04d" $port)
    porthigh="2${portpadded}"
    cat << EOF > ${SERVICE_HOME}/mailhosts/${portcfg}.conf
server {
    listen ${porthigh};
    server_name localhost;
    protocol ${protocol};
    auth_http ${NGINX_MAIL_AUTH_HTTP};
    ${sslconf}
    ${xclient}
    ${proxy_errmsg}
}
EOF
  done
fi

if [ "${NGINX_PHP_FPM_HOST}" != "" ]; then
  cat << EOF > ${SERVICE_HOME}/sites/default-php-fpm.conf
upstream backend {
  server ${NGINX_PHP_FPM_HOST}:${NGINX_PHP_FPM_PORT};
}

server {
  listen 8080 default_server;

  server_name localhost;

  access_log /dev/stdout;
  error_log /dev/stderr;

  root /var/www/html;
  index index.php;

  location ~ /\.ht {
    deny  all;
  }

  location ~* ^.+.(css|js|jpeg|jpg|gif|png|ico) {
    expires 30d;
  }

  location ~ \.php$ {
      fastcgi_pass    backend;
      fastcgi_index   index.php;
      fastcgi_param   SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      include         fastcgi_params;
  }
}

EOF
fi
 
if [ ! -f ${SERVICE_HOME}/sites/*.conf ]; then

    cat << EOF > ${SERVICE_HOME}/sites/example.conf
server {
        listen 8080 default_server;

        root ${SERVICE_HOME}/www;
        index index.html index.htm;

        # Make site accessible from http://localhost/
        server_name localhost;

        location / {

                try_files \$uri \$uri/ /index.html;

        }
}
EOF
fi

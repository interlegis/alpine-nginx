alpine-nginx
=============

This image is the nginx base. It comes from [alpine-monit][alpine-monit].

## Build

```
docker build -t interlegis/alpine-nginx:<version> .
```

## Versions

- `1.10.2-2` [(Dockerfile)](https://github.com/interlegis/alpine-nginx/blob/1.10.2-2/Dockerfile)


## Configuration

This image runs [nginx][nginx] with monit.

Besides, you can customize the configuration in several ways:

### Default Configuration

nginx is installed with the default configuration listening at 8080 and 8443 ports. 

In addition, it is possible to config Mail Proxying with the folloging environment variables:

 - NGINX_MAIL_ENABLE: defaults to "false", "true" enables mail proxying.
 - NGINX_MAIL_PROTOCOLS: defaults to "smtp-587 imap-143 pop3-110". It's a list separated by spaces with protocol configuration separated by hyphens, as following:
   - 1st word: name of the protocol (like smtp)
   - 2nd word: port number (like 587. Container will use a high 20k+ port number, like 20587)
   - 3rd word: security mode. Can be "ssl", "starttls" or none. 
 - NGINX_MAIL_AUTH_HTTP: mail authentication script HTTP URL. Defaults to "localhost". 
 - NGINX_MAIL_SSL_ENABLE: whether to enable SSL encryption for mail proxying. Defaults to "false".
 - NGINX_SSL_PATH: folder where nginx searches for certificates. Defaults to "/opt/nginx/certs".


### Custom Configuration

Nginx is installed under /opt/nginx and make use of /opt/nginx/conf/nginx.conf and /opt/nginx/sites/*.conf.

You could also include `FROM rawmind/alpine-nginx` at the top of your `Dockerfile`, and add your site files to /opt/nginx/www and your nginx config to /opt/nginx/sites



[alpine-monit]: https://github.com/rawmind0/alpine-monit/
[nginx]: http://nginx.org/

FQDN=
SUBJECT=

URL="https://$FQDN"
ADMIN_USER=admin
ADMIN_EMAIL=root@localhost.localdomain
DB_USER=wordpress
DB_NAME=wordpress

ADMIN_PASS=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g')
DB_PASS=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g')
echo $ADMIN_PASS > /root/admin-secret.txt
echo $DB_PASS > /root/db-secret.txt
chmod 400 /root/*-secret.txt

amazon-linux-extras install php8.1 mariadb10.5 nginx1 -y
systemctl start mariadb
systemctl enable mariadb
systemctl start php-fpm
systemctl enable php-fpm
systemctl start nginx
systemctl enable nginx

cd /tmp
cat <<EOF > script.sql
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON $DB_NAME.* to $DB_USER@localhost IDENTIFIED BY '$DB_PASS';
FLUSH PRIVILEGES;
EOF
mysql -u root < script.sql
rm -f script.sql

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
export PATH=$PATH:/usr/local/bin

mkdir -p /var/www/wordpress
wp core download --path=/var/www/wordpress
cd /var/www/wordpress
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS
wp core install --url=$URL --title="Wordpress" --admin_user=$ADMIN_USER --admin_password=$ADMIN_PASS --admin_email=$ADMIN_EMAIL

# Setup nginx
mkdir /etc/nginx/ssl
cd /etc/nginx/ssl
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout private.pem -out public.crt -days 365 -subj "$SUBJECT"

cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    access_log  /var/log/nginx/access.log;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name $FQDN;
        root /var/www/wordpress;
        index index.php index.htm;     

        ssl_certificate /etc/nginx/ssl/public.crt;
        ssl_certificate_key /etc/nginx/ssl/private.pem;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ [^/]\.php(/|$) {
            fastcgi_split_path_info ^(.+?\.php)(/.*)$;
            if (!-f \$document_root\$fastcgi_script_name) {
                return 404;
            }

            # Mitigate https://httpoxy.org/ vulnerabilities
            fastcgi_param HTTP_PROXY "";

            fastcgi_pass unix:/run/php-fpm/www.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

            # include the fastcgi_param setting
            include fastcgi_params;
        }
    }
}
EOF
nginx -s reload


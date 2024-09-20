# Laravel Step-By-Step on Lightsail Nginx

Nginx packaged by bitnami. Steps to deploy a laravel app.

## Make server ready

The server comes ready with PHP, MariaDB, Nginx, Git and Composer.

When you have created a new Lightsail Nginx by Bitnami instance, do the following steps.

### Initial script

```bash
sudo apt update && apt upgrade -y
```

### Setup SSH with GitHub

1. **Generate a new SSH key**: Replace `<email>` with your GitHub email. This will generate an SSH key that you can use for authentication with GitHub.

   ```bash
   ssh-keygen -t ed25519 -C "<email>"
   ```

   When prompted, you can either press `Enter` to accept the default location for saving the key or specify a custom path. Optionally, you can add a passphrase for additional security.

2. **Copy the public key**: After generating the key, copy the newly generated public key by running the following command:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Add the key to your GitHub account**:
   - Go to your GitHub account settings.
   - Navigate to **SSH and GPG keys**.
   - Click **New SSH key**.
   - Paste the public key into the key field and give it a recognizable title.

4. **Test connection**

```bash
ssh -T git@github.com
```

### Projects folder

Projects can go many places. I want it in `/opt/bitnami/projects/`.

```bash
sudo mkdir /opt/bitnami/projects

sudo chown bitnami:daemon /opt/bitnami/projects
```

## Set up a new Laravel site

### Create database and user

Using the line below downloads and executes the script to create database on mariadb.

```bash
bash <(curl -s https://raw.githubusercontent.com/channor/bitnami-nginx-laravel/main/create_db.sh)
```

Alternatively download the script and execute.

### Clone repository

Assuming SSH key is created and added to your GitHub account, clone the 

```bash
git clone git@github.com:username/repository.git /opt/bitnami/projects/project_name
```

### Install dependencies

Use --no-dev on production or optionally staging. 

```bash
composer install --optimize-autoloader --no-dev
```

### Environment config

Copy the example .env file, generate APP_KEY and update the configuration.

```bash
cp .env.example .env
php artisan key:generate
nano .env
```

Update
- APP_NAME
- APP_ENV
- APP_URL
- DB_HOST: localhost
- Database details with previous created database, user and password

### Migrate and seed

```bash
php artisan migrate

php artisan db:seed
```

### Folder and file permissions

```bash
sudo chown -R bitnami:daemon .
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
chmod -R 775 storage bootstrap/cache
chmod +x artisan
chmod 640 .env
```

### Set up SSL / HTTPS

Make sure the domain you want is pointing to your server's IP.

```bash
sudo /opt/bitnami/bncert-tool
```

1. Press enter to proceed.
2. Enter domains with a space between.
3. If you did not provide a www.-domain, you will be asked to include www.-domain as well. Choose Yes or No.
4. The press Y to proceed.
5. Enter your email.
6. Enter "Y" to agree.
7. Done, press enter to finnish and exit the tool.

### Create Nginx conf file

Create a new nginx conf for your laravel site. Name it for example `subdomain-domain-com.conf` 
The following conf file redirects to HTTPS and redirects www to non-www. Replace server_name, 
paths to SSL and root of you projects public folder.

Create the conf-file and paste and edit the configuration below.

```bash
sudo nano /opt/bitnami/nginx/conf/server_blocks/subdomain-domain-com.conf
```

```apacheconf
# Redirect all HTTP traffic for your.domain.com to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name your.domain.com;

    # Redirect all HTTP requests to HTTPS
    return 301 https://your.domain.com$request_uri;
}

# Redirect all HTTP traffic for www.your.domain.com to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name www.your.domain.com;

    # Redirect all HTTP requests to HTTPS
    return 301 https://your.domain.com$request_uri;
}

# HTTPS server block for your.domain.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name your.domain.com;

    ssl_certificate /opt/bitnami/nginx/conf/your.domain.com.crt;
    ssl_certificate_key /opt/bitnami/nginx/conf/your.domain.com.key;

    root /opt/bitnami/projects/laravel-root/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/opt/bitnami/php/var/run/www.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}

# HTTPS server block for www.your.domain.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name www.your.domain.com;

    ssl_certificate /opt/bitnami/nginx/conf/your.domain.com.crt;
    ssl_certificate_key /opt/bitnami/nginx/conf/your.domain.com.key;

    return 301 https://your.domain.com$request_uri;
}
```

Restart system

```bash
sudo /opt/bitnami/ctlscript.sh restart
```

### Deploy changes

When changes has been pushed to your repository, pull the changes to your server:

```bash
git pull
bash <(curl -s https://raw.githubusercontent.com/channor/bitnami-nginx-laravel/main/deploy.sh)
```

## Testing and staging

It's always nice to test the new commits in a staging environment before pulling the changes to production.

1. Do the same steps as in [Set up a new Laravel site](#set-up-a-new-laravel-site).
2. Open your local hosts file and add `120.0.0.1 your-domain.test`
3. Use the same server block as above.

### Restrict to SSH and local host access only

If you want, make access to the staging environment only accessable from 120.0.0.1 host through SSH tunnel.

1. Add restriction to the conf-file:

```apacheconf
if ($remote_addr != 127.0.0.1) {
  return 403 'For security reasons, this URL is only accessible using localhost (127.0.0.1) as the hostname.';
}
```

2. Add self-signed SSL-certificate

```apacheconf
ssl_certificate /opt/bitnami/nginx/conf/bitnami/certs/server.crt;
ssl_certificate_key /opt/bitnami/nginx/conf/bitnami/certs/server.key;
```

3. Set up SSH tunnel

```bash
ssh -N -L 443:127.0.0.1:443 -i lightsail.pem bitnami@<instance-public-ip>
```

or the following for http://

```bash
ssh -N -L 8888:127.0.0.1:80 -i lightsail.pem bitnami@<instance-public-ip>
```

## Paths that is commonly used

- **Main nginx conf**: `/opt/bitnami/nginx/conf/nginx.conf`
- **Bitnami conf folder**: `/opt/bitnami/nginx/conf/bitnami/`
- **Server block included in nginx.conf http block**: `/opt/bitnami/nginx/conf/server_blocks/`

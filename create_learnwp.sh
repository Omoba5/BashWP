#!/bin/bash

# Absolute Path of Script
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SITENAME=$1

# Step 1: Ensure all apps are up to date
sudo apt update
# sudo apt upgrade -y

# Have a short break to ensure the updates are completed before installation of Server Stack.
sleep 10

# Step 2: Install the necessary applications
sudo apt install mysql-server -y
sudo apt install php-fpm nginx php-mysql -y

# Have a short break to ensure the installations are completed.
sleep 15

# Start the services
sudo systemctl start nginx mysql php8.1-fpm
sudo systemctl enable nginx mysql php8.1-fpm

# Install other Wordpress dependencies for full functionality
sudo apt install -y php-curl php-common php-imagick php-mbstring php-xml php-zip php-json php-xmlrpc php-gd

# Have a short break to ensure the installations are completed.
sleep 15

# Ask the User for some Website name, username and passwords.
# read -p "Enter your choice Website Name, lowercase alphabets ONLY: " SITENAME
# echo -e "Your website name is: ${SITENAME} which doubles as your USERNAME"
# read -p "Enter your preferred Password, NO SPACES ALLOWED: " -s pswrd && echo

# Delete previous nginx configuration file and create our default one.
sudo rm /etc/nginx/nginx.conf
sudo cp ${DIR}/nginx.conf /etc/nginx/

# Create the cache directory
sudo mkdir -p /usr/share/nginx/cache/fcgi

# Next we will configure PHP-FPM first by creating the directory for it's socket.
sudo mkdir /run/php-fpm

# Delete previous php-fpm configuration file and create our default one.
sudo rm /etc/php/8.1/fpm/php-fpm.conf
sudo cp ${DIR}/php-fpm.conf /etc/php/8.1/fpm/

# Remove the original (default) pool config file and make another
sudo rm /etc/php/8.1/fpm/pool.d/www.conf
sudo cp ${DIR}/site-php.conf /etc/php/8.1/fpm/pool.d/
sudo sed -i "s/yourSITENAME/${SITENAME}/g" /etc/php/8.1/fpm/pool.d/site-php.conf

# Delete previous php.ini file and create our default one.
sudo rm /etc/php/8.1/fpm/php.ini
sudo cp ${DIR}/php.ini /etc/php/8.1/fpm/

# Next we configure MySQL first by creating a strong password
rootword=$(openssl rand -base64 12)

# Set password with `debconf-set-selections` no need to enter it in prompt
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${rootword}" # new password for the MySQL root user
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${rootword}" # repeat password for the MySQL root user

# Other Code.....
sudo mysql --user=root --password=${rootword} << EOF
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

# Note down this password. Else you will lose it and you may have to reset the admin password in mySQL
echo -e "SUCCESS! MySQL password is: ${rootword}" 

sudo systemctl restart mysql

# Create the User account and make a log file for the running applications
sudo useradd -s /bin/bash -m -d /home/${SITENAME} ${SITENAME} --password=${passwrd}
sudo mkdir -p /home/${SITENAME}/logs

# Set the appropriate permissions
sudo chown -R ${SITENAME}:www-data /home/${SITENAME}
sudo chmod 775 /home/${SITENAME}

# Create nginx vhost config file
sudo cp ${DIR}/site-nginx.conf /etc/nginx/conf.d/
sudo sed -i "s/yourSITENAME/${SITENAME}/g" /etc/nginx/conf.d/site-nginx.conf


# Disable default nginx vhost
sudo rm /etc/nginx/sites-enabled/default

# Create the php-fpm log file
sudo -u ${SITENAME} touch /home/${SITENAME}/logs/phpfpm_error.log

# Create Site Database and Database User
DBpswd=$(openssl rand -base64 12)
sudo mysql --user=root --password=${DBpswd} << EOF
CREATE DATABASE ${SITENAME};
CREATE USER '${SITENAME}'@'localhost' IDENTIFIED BY '${DBpswd}';
GRANT ALL PRIVILEGES ON ${SITENAME}.* TO ${SITENAME}@localhost;
FLUSH PRIVILEGES;
EOF

echo
echo
echo "SQL SETUP COMPLETE, PROCEEDING TO WORDPRESS INSTALLATION"
echo
echo

# Installing Wordpress as the Website user
wget "https://wordpress.org/wordpress-6.1.1.tar.gz"
tar zxf wordpress-6.1.1.tar.gz
rm wordpress-6.1.1.tar.gz
sudo mv wordpress /home/${SITENAME}/public_html

# Ensuring we don't get ahead of ourselves
sleep 20

# Setting proper file permissions on the website
cd /home/${SITENAME}/public_html
sudo chown -R ${SITENAME}:www-data .
sudo find . -type d -exec chmod 755 {} \;
sudo find . -type f -exec chmod 644 {} \;

# Restarting the configured services
sudo systemctl restart php8.1-fpm
sudo systemctl restart nginx

cat << EOF 
Congratulations! Wordpress has being successfully installed.

Your username which is also your website name is ${SITENAME}

Your Database Name is ${SITENAME}

Your Database password is ${DBpswd} running @localhost

Your MySQL root password is ${rootword}
EOF

echo "NOTE: Copy and run this command after WordPress installation:" 
echo
echo "chmod 640 /home/${SITENAME}/public_html/wp-config.php"

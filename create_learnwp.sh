#!/bin/bash

# Absolute Path of Script
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


# Step 1: Ensure all apps are up to date
sudo apt update
sudo apt ugrade -y

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
read -p "Enter your choice Website Name, lowercase alphabets ONLY: " sitename
echo -e "Your website name is: ${sitename} which doubles as your USERNAME"
read -p "Enter your preferred Password, NO SPACES ALLOWED: " -s pswrd && echo

# Delete previous nginx configuration file and create our default one.
sudo rm /etc/nginx/nginx.conf
sudo cp $DIR/nginx.conf /etc/nginx/

# Create the cache directory
sudo mkdir -p /usr/share/nginx/cache/fcgi

# Next we will configure PHP-FPM first by creating the directory for it's socket.
sudo mkdir /run/php-fpm

# Delete previous php-fpm configuration file and create our default one.
sudo rm /etc/php/8.1/fpm/php-fpm.conf
sudo cp $DIR/php-fpm.conf /etc/php/8.1/fpm/

# Remove the original (default) pool config file and make another
sudo rm /etc/php/8.1/fpm/pool.d/www.conf
sudo cp $DIR/site-php.conf /etc/php/8.1/fpm/pool.d/

# Delete previous php.ini file and create our default one.
sudo rm /etc/php/8.1/fpm/php.ini
sudo cp $DIR/php.ini /etc/php/8.1/fpm/

# Next we configure MySQL first by creating a strong password
rootword=$(openssl rand -base64 12)

# Set password with `debconf-set-selections` You don't have to enter it in prompt
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

systemctl restart mysql

# Create the User account and make a log file for the running applications
sudo useradd -s /bin/bash -m -d /home/${sitename} ${sitename}
sudo mkdir -p /home/${sitename}/logs

# Set the appropriate permissions
sudo chown -R ${sitename}:www-data /home/${sitename}
sudo chmod 775 /home/${sitename}

# Disable default nginx vhost
sudo rm /etc/nginx/sites-enabled/default

# Create the php-fpm log file
sudo -u ${sitename} touch /home/${sitename}/logs/phpfpm_error.log

# Create Site Database and Database User
DBpswd=$(openssl rand -base64 12)
sudo mysql --user=root --password=${DBpswd} << EOF
CREATE DATABASE ${sitename};
CREATE USER '${sitename}'@'localhost' IDENTIFIED BY '${DBpswd}';
GRANT ALL PRIVILEGES ON ${sitename}.* TO ${sitename}@localhost;
FLUSH PRIVILEGES;
EOF

# Installing Wordpress as the Website user
su ${sitename}
cd /home/${sitename}
wget https://wordpress.org/latest.tar.gz

# Ensuring we don't get ahead of ourselves
sleep 20
# Cleaning up
tar zxf latest.tar.gz
rm latest.tar.gz
# Exiting user shell
exit

# Setting proper file permissions on the website
cd /home/${sitename}/public_html
chown -R ${sitename}:www-data .
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

# Restarting the configured services
systemctl restart php8.1-fpm
systemctl restart nginx

cat << EOF 
Congratulations! Wordpress has being successfully installed.
Your username which is also your website name is ${sitename}
Your Databade username is ${sitename}
Your Database password is ${DBpswd} running @localhost
Your MySQL root password is ${rootword}
EOF

echo "Copy and run this command after WordPress installation:" 
echo "chmod 640 /home/${sitename}/public_html/wp-config.php"
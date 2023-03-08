This is a Bash Shell Script for an Automated installation of a LEMP server.
LEMP - Linux Nginx MySQL PHP


Software requirements
Ubuntu 20.04 Focal
unzip

The user will be required to enter the Website alone during the installation.
At the end of the successful execution (~5mins), the user will get the:

1. Database Name
2. Database Password
3. MySQL root Password

These are needed for complete the Wordpress installation via the front end.

Lastly, the command "chmod 640 /home/${sitename}/public_html/wp-config.php"
must be ran after completing the WordPress installation just for security.
No one else will be able to read the Database credentials.
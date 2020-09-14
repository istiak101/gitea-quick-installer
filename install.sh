#!/bin/bash
# Gitea Installer By Istiak Ferdous
# Author: Istiak Ferdous
# Website: https://istiakferdous.com
# Email: hello@istiakferdous.com

# Take all input
echo -e "Please enter new root password for MySQL: "
read mysqlrootpass
echo -e "Please enter database name you want to use for Gitea: "
read giteadbname
echo -e "Please enter database username you want to use for Gitea Database($giteadbname): "
read giteadbuser
echo -e "Please enter database password you want to use for Gitea($giteadbuser): "
read giteadbpass
echo -e "Please enter system username you want to use for Gitea: "
read giteauser

# Update everything first
yum update -y

# Install Git now
yum -y install git

# Install MariaDB for database
yum -y install mariadb-server

# Enable MariaDB on boot and start the server
systemctl enable mariadb.service
systemctl start mariadb.service

# MySQL Secure Installation
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$mysqlrootpass') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

# Restart MariaDB now
systemctl restart mariadb.service

# Create database and assign a user
echo "Creating database and assigning user..."
mysql -u root -p"$mysqlrootpass" <<-EOF
CREATE DATABASE $giteadbname;
CREATE USER '$giteadbuser'@'localhost' IDENTIFIED BY '$giteadbpass';
GRANT ALL ON $giteadbname.* TO '$giteadbuser'@'localhost' IDENTIFIED BY '$giteadbpass' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# Add user for Gitea
adduser --system --shell /bin/bash --comment 'Git Version Control' --user-group --home-dir /home/$giteauser -m $giteauser

# Create directory structure
mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
chown $giteauser:$giteauser /var/lib/gitea/{data,indexers,log}
chmod 750 /var/lib/gitea/{data,indexers,log}
mkdir /etc/gitea
chown root:$giteauser /etc/gitea
chmod 770 /etc/gitea

# Download & Install Gitea
wget -O gitea https://dl.gitea.io/gitea/1.12.4/gitea-1.12.4-linux-amd64
chmod +x gitea
cp gitea /usr/local/bin/gitea

# Create Gitea Service
touch /etc/systemd/system/gitea.service

cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target
After=mariadb.service

[Service]
# Modify these two values and uncomment them if you have
# repos with lots of files and get an HTTP error 500 because
# of that
###
#LimitMEMLOCK=infinity
#LimitNOFILE=65535
RestartSec=2s
Type=simple
User=$giteauser
Group=$giteauser
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=always
Environment=USER=$giteauser HOME=/home/$giteauser GITEA_WORK_DIR=/var/lib/gitea
# If you want to bind Gitea to a port below 1024 uncomment
# the two values below
###
#CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Enable & Start Gitea at boot
systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# Check if Gitea is running
systemctl status gitea

# Firewall setup
sudo firewall-cmd --add-port 3000/tcp --permanent
sudo firewall-cmd --reload

# Print all password and necessary instructions needed later
echo "******************************************************"
echo "MySQL root password: $mysqlrootpass"
echo "Gitea database name: $giteadbname"
echo "Gitea database username: $giteadbuser"
echo "Gitea database password: $giteadbpass"
echo "******************************************************"

# Get IP
ip=$(hostname -I)
echo "Now go to browser and type: http://$ip:3000/install"

exit 0

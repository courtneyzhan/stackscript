#!/bin/bash

exec &> /root/stackscript.log

DEPLOY_USER=courtney
DEPLOY_PASSWORD=password
RUBY_VERSION=3.0.2

function log {
  echo "### $1 -- `date '+%D %T'`"
}

function lower {
    # helper function
    echo $1 | tr '[:upper:]' '[:lower:]'
}

# gcc make seems not install
function install_essentials {
  apt-get -y install  git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev
}


function system_add_user {
    # system_add_user(username, password, groups, shell=/bin/bash)
    USERNAME=`lower $1`
    PASSWORD=$2
    SUDO_GROUP=$3
    SHELL=$4
    if [ -z "$4" ]; then
        SHELL="/bin/bash"
    fi
    useradd --create-home --shell "$SHELL" --user-group --groups "$SUDO_GROUP" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
}

function create_deployment_user {
  system_add_user $DEPLOY_USER $DEPLOY_PASSWORD "users,sudo"
}

log "Updating System..."
yes Y | apt-get update

log "Installing essentials...includes gcc make?"
apt-get -y install gcc
apt-get -y install g++
apt-get -y install make
install_essentials

log "Install MySQL Client and Sqlite3"
apt-get -y install mysql-client libmysqlclient-dev
apt-get -y install sqlite3

log "Install Node.js for compiling JS"
apt-get -y install nodejs
apt-get -y install npm
npm install --global yarn

log "Creating deployment user $DEPLOY_USER"
create_deployment_user

cat >> /etc/sudoers <<EOF
Defaults !secure_path
$DEPLOY_USER ALL=(ALL) NOPASSWD: ALL
EOF

log "Install nginx"
apt-get -y install nginx


log "Create /opt folder"
chown -R $DEPLOY_USER /opt
mkdir /var/www
mkdir /var/www/rails
chown -R $DEPLOY_USER /var/www

#log "Auto-start Ngnix - Nginx not installed yet"
#wget -O init-deb.sh http://library.linode.com/assets/660-init-deb.sh
#mv init-deb.sh /etc/init.d/nginx
#chmod +x /etc/init.d/nginx
#/usr/sbin/update-rc.d -f nginx defaults

log "Install rbenv"
su $DEPLOY_USER -c "git clone https://github.com/rbenv/rbenv.git /home/$DEPLOY_USER/.rbenv"
su $DEPLOY_USER -c "git clone git://github.com/sstephenson/ruby-build.git /home/$DEPLOY_USER/.rbenv/plugins/ruby-build"
su $DEPLOY_USER -c "echo 'export PATH="/home/$DEPLOY_USER/.rbenv/bin:/home/$DEPLOY_USER/.rbenv/plugins/ruby-build/bin:$PATH"' >> /home/$DEPLOY_USER/.bash_profile"
echo 'eval "$(rbenv init -)"' >> /home/courtney/.bash_profile



su $DEPLOY_USER -c "cd; source /home/$DEPLOY_USER/.bash_profile"


log "Install and configure passenger"

sudo apt-get install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo apt-get install -y apt-transport-https ca-certificates

sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list'
sudo apt-get update
sudo apt-get install -y libnginx-mod-http-passenger

# https://www.phusionpassenger.com/docs/advanced_guides/install_and_upgrade/nginx/install/oss/focal.html

log "git clone rails project to /var/www/rails"
su $DEPLOY_USER -c "mkdir -p /var/www/rails"
su $DEPLOY_USER -c "cd /var/www/rails; git clone https://github.com/courtneyzhan/sample-rails6-bootstrap5 sample-rails6-bootstrap5"


log "Install Ruby, this might take a while"

cat >> /home/$DEPLOY_USER/install_ruby.sh <<EOF
rbenv install -v $RUBY_VERSION
rbenv global $RUBY_VERSION
gem install --no-document rails
EOF

# leave it to user to run if necesasary
chmod +x  /home/$DEPLOY_USER/install_ruby.sh
chown  $DEPLOY_USER  /home/$DEPLOY_USER/install_ruby.sh

# root will run the install_ruby as $DEPLOY_USER
su -l $DEPLOY_USER -c /home/$DEPLOY_USER/install_ruby.sh

#  the ruby version used by passenger: /usr/bin/passenger_free_ruby;
# defined in
# /etc/nginx/conf.d/mod-http-passenger.conf


log "TODO: configure ruby on rails deployment: wget deploy under /etc/nginx"
chown -R  $DEPLOY_USER /etc/nginx/sites-available
chown -R  $DEPLOY_USER /etc/nginx/sites-enabled

su $DEPLOY_USER -c "cp /var/www/rails/sample-rails6-bootstrap5/config/deploy/nginx-sites* /etc/nginx/sites-available"
su $DEPLOY_USER -c "rm /etc/nginx/sites-enabled/default"
su $DEPLOY_USER -c "ln -s /etc/nginx/sites-available/nginx-sites-development /etc/nginx/sites-enabled"


cat >> /home/$DEPLOY_USER/deploy-rails.sh <<EOF
cd /var/www/rails/sample-rails6-bootstrap5
git pull origin master
bundle
rake RAILS_ENV=development db:migrate
rake RAILS_ENV=development assets:precompile
touch /var/www/rails/sample-rails6-bootstrap5/tmp/restart.txt
EOF
chmod +x  /home/$DEPLOY_USER/deploy-rails.sh 
chown $DEPLOY_USER /home/$DEPLOY_USER/deploy-rails.sh 

# root will run the deployment as $DEPLOY_USER
su -l $DEPLOY_USER -c /home/$DEPLOY_USER/deploy-rails.sh 

log "Restart Nginx"
systemctl restart nginx

log "Done!"

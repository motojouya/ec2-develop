#!/bin/bash
set -x

# definitions
export AWS_DEFAULT_REGION=ap-northeast-1

region=$1
userid=$2
username=$3
password=$4
ssh_port=$5
hosted_zone_id=$6
domain=$7
volume_id=$8

instance_id=$(curl -s 169.254.169.254/latest/meta-data/instance-id)
ip=$(curl -s 169.254.169.254/latest/meta-data/public-ipv4)

cd /home/ubuntu

# install awscli
apt update
apt install -y python3-pip
pip3 install awscli

# mount ebs volume
aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/xvdb --region $region
aws ec2 wait volume-in-use --volume-ids $volume_id
until [ -e /dev/nvme1n1 ]; do
    sleep 1
done
mkdir /home/$username
# mkfs -t ext4 /dev/nvme1n1
mount /dev/nvme1n1 /home/$username

# add user
useradd -u $userid -d /home/$username -s /bin/bash $username
gpasswd -a $username sudo
cp -arpf /home/ubuntu/.ssh/authorized_keys /home/$username/.ssh/authorized_keys
chown $username /home/$username
chgrp $username /home/$username
chown -R $username /home/$username/.ssh
chgrp -R $username /home/$username/.ssh
echo "$username:$password" | chpasswd

# register route53
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/dyndns.tmpl -O
sed -e "s/{%IP%}/$ip/g;s/{%domain%}/$domain/g" dyndns.tmpl > change_resource_record_sets.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///home/ubuntu/change_resource_record_sets.json

# ssh config
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/sshd_config.tmpl -O
sed -e s/{%port%}/$ssh_port/g sshd_config.tmpl > sshd_config.init
cp sshd_config.init /etc/ssh/sshd_config
systemctl restart sshd

# install nodejs
apt install -y nodejs
apt install -y npm

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt update
apt install -y yarn
npm install -g npx
yarn global add create-react-app

# install docker
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

gpasswd -a $username docker
systemctl restart docker

# install nginx
# https://certbot.eff.org/lets-encrypt/ubuntubionic-nginx
apt install -y nginx
apt install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y ppa:certbot/certbot
apt update
apt install -y certbot python-certbot-nginx

cp /home/$user/letsencrypt.tar.gz
tar xzf letsencrypt.tar.gz
cd /etc/letsencrypt/live/$domain
ln -s ../../archive/$domain/cert1.pem cert.pem
ln -s ../../archive/$domain/chain1.pem chain.pem
ln -s ../../archive/$domain/fullchain1.pem fullchain.pem
ln -s ../../archive/$domain/privkey1.pem privkey.pem

# certbot certonly --standalone -d motojouya-devdev.tk -m motojouya@gmail.com --agree-tos -n --dry-run

# before /etc/letsencrypt/cli.ini
# # Because we are using logrotate for greater flexibility, disable the
# # internal certbot logrotation.
# max-log-backups = 0

# m$ sudo tree /etc/letsencrypt/
# /etc/letsencrypt/
# ├── accounts
# │   └── acme-v02.api.letsencrypt.org
# │       └── directory
# │           └── afadd590502fee53a5a38f5c6822425e
# │               ├── meta.json
# │               ├── private_key.json
# │               └── regr.json
# ├── archive
# │   └── motojouya-devdev.tk
# │       ├── cert1.pem
# │       ├── chain1.pem
# │       ├── fullchain1.pem
# │       └── privkey1.pem
# ├── cli.ini
# ├── csr
# │   ├── 0000_csr-certbot.pem
# │   ├── 0001_csr-certbot.pem
# │   ├── 0002_csr-certbot.pem
# │   ├── 0003_csr-certbot.pem
# │   └── 0004_csr-certbot.pem
# ├── keys
# │   ├── 0000_key-certbot.pem
# │   ├── 0001_key-certbot.pem
# │   ├── 0002_key-certbot.pem
# │   ├── 0003_key-certbot.pem
# │   └── 0004_key-certbot.pem
# ├── live
# │   ├── README
# │   └── motojouya-devdev.tk
# │       ├── README
# │       ├── cert.pem -> ../../archive/motojouya-devdev.tk/cert1.pem
# │       ├── chain.pem -> ../../archive/motojouya-devdev.tk/chain1.pem
# │       ├── fullchain.pem -> ../../archive/motojouya-devdev.tk/fullchain1.pem
# │       └── privkey.pem -> ../../archive/motojouya-devdev.tk/privkey1.pem
# ├── renewal
# │   └── motojouya-devdev.tk.conf
# └── renewal-hooks
#     ├── deploy
#     ├── post
#     └── pre

# install others
apt install -y neovim
apt install -y jq
apt  install -y tree

cd /
userdel -r ubuntu


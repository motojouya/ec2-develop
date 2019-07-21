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
cp -p /etc/apt/sources.list /etc/apt/sources.list.bak
sed -i 's/ap-northeast-1\.ec2\.//g' /etc/apt/sources.list
apt update
apt install nvme-cli
apt install -y unzip
apt install -y python
# DEBIAN_FRONTEND=noninteractive dpkg --configure -a --force-confdef --force-confnew
# apt install -y python3-pip
# pip3 install awscli
if ! test -e /usr/bin/aws ; then
  curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip"
  unzip /tmp/awscli-bundle.zip -d /tmp
  /tmp/awscli-bundle/install -i /usr/lib/aws -b /usr/bin/aws
fi

# mount ebs volume
aws ec2 attach-volume --volume-id vol-$volume_id --instance-id $instance_id --device /dev/xvdb --region $region
aws ec2 wait volume-in-use --volume-ids vol-$volume_id
device=$(nvme list | grep $volume_id | awk '{print $1}' | xargs)
until [ -n $device ]; do
    sleep 1
    device=$(nvme list | grep $volume_id | awk '{print $1}' | xargs)
done
# until [ -e $device ]; do
#     sleep 1
# done
mkdir /home/$username
# mkfs -t ext4 $device
mount $device /home/$username

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
npm install -g typescript typescript-language-server
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

# install nginx and certbot for let's encrypt
cd /etc
cp /home/$username/letsencrypt.tar.gz letsencrypt.tar.gz
tar xzf letsencrypt.tar.gz
cd /home/ubuntu

apt install -y nginx
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/http.conf.tmpl -O
sed -e s/{%domain%}/$domain/g http.conf.tmpl > http.conf
cp http.conf /etc/nginx/conf.d/http.conf

apt install -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y ppa:certbot/certbot
apt update
apt install -y certbot python-certbot-nginx

# install library for puppeteer
# apt install -y gconf-service libasound2 libatk1.0-0 libatk-bridge2.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 ca-certificates fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils wget

# install others
apt install -y neovim
apt install -y jq
apt install -y tree

git config --global core.editor 'vim -c "set fenc=utf-8"'

cd /
userdel -r ubuntu


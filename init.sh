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

curl -L https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

gpasswd -a $username docker
systemctl restart docker

# install others
apt install -y neovim
apt install -y jq

cd /
userdel -r ubuntu


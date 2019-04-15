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

# update install
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
useradd -u $userid -d /home/$username -s /bin/bash $username
gpasswd -a $username sudo
cp -arpf /home/ubuntu/.ssh /home/$username/
chown -R $username /home/$username/.ssh
echo "$username:$password" | chpasswd
userdel -r ubuntu

# register route53
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/dyndns.tmpl -O
sed -e "s/{%IP%}/$ip/g;s/{%domain%}/$domain/g" dyndns.tmpl > change_resource_record_sets.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///change_resource_record_sets.json

# ssh config
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/sshd_config.tmpl -O
sed -e s/{%port%}/$ssh_port/g sshd_config.tmpl > sshd_config.init
cp sshd_config.init /etc/ssh/sshd_config
systemctl restart sshd


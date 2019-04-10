#!/bin/bash
set -x

# definitions
export AWS_DEFAULT_REGION=ap-northeast-1

region=$1
userid=$2
username=$3
hosted_zone_id=$4
domain=$5
volume_id=$6

instance_id=$(curl -s 169.254.169.254/latest/meta-data/instance-id)
ip=$(curl -s 169.254.169.254/latest/meta-data/public-ipv4)

# update install
sudo apt update
sudo apt install python3-pip
sudo pip3 install awscli

# mount ebs volume
sudo aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/xvdb --region $region
sudo mkdir /home/$username
# sudo mkfs -t ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /home/$username
sudo useradd -u $userid -d /home/$username $username

# register route53
curl https://raw.githubusercontent.com/motojouya/ec2-develop/master/dyndns.tmpl -O
sed -e "s/{%IP%}/$ip/g;s/{%domain%}/$domain/g" dyndns.tmpl > change_resource_record_sets.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///home/ubuntu/change_resource_record_sets.json


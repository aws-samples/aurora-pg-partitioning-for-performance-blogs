#/bin/bash
sudo tee /etc/yum.repos.d/pgdg.repo<<EOF
[pgdg12]
name=PostgreSQL 12 for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0
EOF
sudo yum makecache

sudo yum install jq -y
sudo yum install postgresql12 -y


#read -p 'Enter BastionStack  stack name: ' BASTION_STACK_NAME
#BastionHostRole=$(aws cloudformation describe-stacks --stack-name $BASTION_STACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="BastionHostRole") | .OutputValue')

#echo "Bastion Host Role used is" $BastionHostRole
#echo "Before processding, Attachg AWSCloudFormationFullAccess to Bastion Host Role"

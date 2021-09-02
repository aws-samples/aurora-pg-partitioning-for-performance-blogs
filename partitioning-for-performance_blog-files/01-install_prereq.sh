#!/bin/bash

help () {

printf "Script: 01-install_prereq.sh\n"
printf "Usage: 01-install_prereq.sh [ -s ] [ -r ]\n"
printf " -- \nWhere: \n"
printf "   -s  The inital AWS Stack name which is to create the vpc, subnet, and Aurora cluster. \n"
printf "       Whatever value is set when running script 01-install_prereq.sh is what should be retained\n"
printf "       for the rest of the demo scripts. This flag can be avoided if AURORA_DB_CFSTACK_NAME is \n"
printf "       set as an environment variable. \n"
printf "   -r  The AWS Region we're running this demo in. This setting needs to stay the same across all scripts run.\n"
printf "       Using this flag can be avoided if AWS_DEFAULT_REGION is set as an environment variable where running this script\n"
printf "   -h  show help page.\n"

}

while getopts 's:r:h' flag; do
  case "${flag}" in
    s) AURORA_DB_CFSTACK_NAME="${OPTARG}" ;;
    r) AWS_DEFAULT_REGION="${OPTARG}" ;;
    h) show_help='true' ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

if [[  $show_help == "true" ]]
then
    help
    exit 0
fi

if [ -z $AURORA_DB_CFSTACK_NAME ]
then
    printf "The AWS stack var isn't set. Please use -s to set this stack, and ensure it's already completed sucessfully.\n"
    help
    exit 1
else
    printf "The AWS Stack is set, continuing.\n"
fi

if [ -z $AWS_DEFAULT_REGION ]
then
    printf "The AWS default region var isn't set. Please use -r to set this stack.\n"
    help
    exit 1
else
    printf "The AWS default region is set, continuing.\n"
fi

## Mainline


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

echo "Enabling logical replication for your PostgeSQL Database"
 
echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

echo "Enabling logical replication..."
CLUSTER_PARAM_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterParameterGroup')
DB_INSTANCE_IDENTIFIER=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterMembers[].DBInstanceIdentifier')

aws rds modify-db-cluster-parameter-group --db-cluster-parameter-group-name $CLUSTER_PARAM_GROUP --parameters "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot"

aws rds reboot-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER

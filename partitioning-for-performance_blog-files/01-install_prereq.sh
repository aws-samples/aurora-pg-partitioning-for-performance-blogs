#!/bin/bash

unset AWS_DEFAULT_REGION

while getopts 's:r:ch' flag; do
  case "${flag}" in
    s) AURORA_DB_CFSTACK_NAME="${OPTARG}" ;;
    r) AWS_DEFAULT_REGION="${OPTARG}" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

# Check that region var is set
if [ -z $AURORA_DB_CFSTACK_NAME ]
then
    printf "The AWS stack var isn't set. Please use -s to set this stack, and ensure it's already completed sucessfully.\n"
    exit 1
else
    printf "The AWS Stack is set, continuing.\n"
fi

# Check that region var is set
if [ -z $AWS_DEFAULT_REGION ]
then
    printf "The AWS default region var isn't set. Please use -r to set this stack.\n"
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

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

echo "Disabling logical replication for your PostgeSQL Database"
 
echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

CLUSTER_PARAM_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterParameterGroup')
DB_INSTANCE_IDENTIFIER=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterMembers[].DBInstanceIdentifier')

aws rds modify-db-cluster-parameter-group --db-cluster-parameter-group-name $CLUSTER_PARAM_GROUP --parameters "ParameterName=rds.logical_replication,ParameterValue=0,ApplyMethod=pending-reboot"

aws rds reboot-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER

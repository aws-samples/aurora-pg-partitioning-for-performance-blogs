#!/bin/bash

unset AWS_DEFAULT_REGION

while getopts 's:r:ch' flag; do
  case "${flag}" in
    s) AWSDMS_CFSTACK_NAME="${OPTARG}" ;;
    r) AWS_DEFAULT_REGION="${OPTARG}" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

# Check that region var is set
if [ -z $AWSDMS_CFSTACK_NAME ]
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

##Mainline

#Set variable to replication instance arn
DMSREP_INSTANCE_ARN=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ReplicationInstanceArn") | .OutputValue')


DMS_TASK_ARN1=$(aws dms describe-replication-tasks | jq -r  '.ReplicationTasks[]|select(.ReplicationTaskIdentifier=="dms-task-partitioning")|.ReplicationTaskArn')
echo "Replication task ARN:" $DMS_TASK_ARN1


echo "Stop replication task"

aws dms stop-replication-task --replication-task-arn ${DMS_TASK_ARN1}

echo "Waiting on replication task to stop"
sleep 60;

echo "Check status of replication task"

aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" --output table

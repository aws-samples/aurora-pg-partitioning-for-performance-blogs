#!/bin/bash

help () {

printf "Script: 05-start-replication-task.sh \n"
printf "Usage: 05-start-replication-task.sh [ -d ] [ -r ] [ -h ] \n"
printf " -- \nWhere: \n"
printf "   -d  This flag sets the CFT stack name for the stack in which all DMS resources are created.\n"
printf "       This flag can be avoided if AWSDMS_CFSTACK_NAME is set as an environment variable.\n"
printf "   -r  The AWS Region we're running this demo in. This setting needs to stay the same across all scripts run.\n"
printf "       Using this flag can be avoided if AWS_DEFAULT_REGION is set as an environment variable where running this script\n"
printf "   -h  show help page.\n"

}

while getopts 's:r:h' flag; do
  case "${flag}" in
    d) AWSDMS_CFSTACK_NAME="${OPTARG}" ;;
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

if [ -z $AWSDMS_CFSTACK_NAME ]
then
    printf "The AWS DMS stack var isn't set. Please use -s to set this stack, and ensure it's already completed sucessfully.\n"
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

##Mainline

#/bin/bash

#Set variable to replication instance arn
DMSREP_INSTANCE_ARN=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ReplicationInstanceArn") | .OutputValue')

REPLICATION_TASK_STATUS=""
while [ "$REPLICATION_TASK_STATUS" != "ready" ];
do
  echo "waiting for replication task to be created"
  REPLICATION_TASK_STATUS=$(aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" | jq -r  '.[].ReplicationTaskStatus')
  echo "Replication task status is": $REPLICATION_TASK_STATUS
  sleep 10;
done

DMS_TASK_ARN1=$(aws dms describe-replication-tasks | jq -r  '.ReplicationTasks[]|select(.ReplicationTaskIdentifier=="dms-task-partitioning")|.ReplicationTaskArn')
echo "Replication task ARN:" $DMS_TASK_ARN1


echo "Start replication task"

aws dms start-replication-task --replication-task-arn ${DMS_TASK_ARN1} --start-replication-task-type start-replication

echo "Waiting on replication task to start"
sleep 60;

echo "Check status of replication task"

aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" --output table



#!/bin/bash

help () {

printf "Script: 11-cleanup.sh\n"
printf "Usage: 11-cleanup.sh [ -s ] [ -r ] [ -d ] [ -h ] \n"
printf " -- \nWhere: \n"
printf "   -s  The inital AWS Stack name which is to create the vpc, subnet, and Aurora cluster. \n"
printf "       Whatever value is set when running script 01-install_prereq.sh is what should be retained\n"
printf "       for the rest of the demo scripts. This flag can be avoided if AURORA_DB_CFSTACK_NAME is \n"
printf "       set as an environment variable. \n"
printf "   -r  The AWS Region we're running this demo in. This setting needs to stay the same across all scripts run.\n"
printf "       Using this flag can be avoided if AWS_DEFAULT_REGION is set as an environment variable where running this script\n"
printf "   -d  This flag sets the CFT stack name for the stack in which all DMS resources are created.\n"
printf "       This flag can be avoided if AWSDMS_CFSTACK_NAME is set as an environment variable.\n"
printf "   -h  show help page.\n"

}

while getopts 's:r:d:h' flag; do
  case "${flag}" in
    s) AURORA_DB_CFSTACK_NAME="${OPTARG}" ;;
    r) AWS_DEFAULT_REGION="${OPTARG}" ;;
    d) AWSDMS_CFSTACK_NAME="${OPTARG}" ;;
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

if [ -z $AWSDMS_CFSTACK_NAME ]
then
    printf "The DMS resource stackname var isn't set. Please use -d to set this stack.\n"
    help
    exit 1
else
    printf "The DMS resource stackname is set, continuing.\n"
fi

## Mainline

SrcRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')

export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"

#Set variable to replication instance arn
DMSREP_INSTANCE_ARN=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ReplicationInstanceArn") | .OutputValue')

echo "DMS instance ARN:" $DMSREP_INSTANCE_ARN

#source and target endpoint
DB_TGT_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="TgtEndpointArn") | .OutputValue')
DB_SRC_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SrcEndpointArn") | .OutputValue')

echo "DB taget endpoint:" $DB_TGT_ENDPOINT
echo "DB source endpoint:" $DB_SRC_ENDPOINT

DMS_TASK_ARN1=$(aws dms describe-replication-tasks | jq -r  '.ReplicationTasks[]|select(.ReplicationTaskIdentifier=="dms-task-partitioning")|.ReplicationTaskArn')
echo "DMS replication task ARN:" $DMS_TASK_ARN1

echo "stop replication task"
aws dms stop-replication-task --replication-task-arn ${DMS_TASK_ARN1} 

REPLICATION_TASK_STATUS=""
while [ "$REPLICATION_TASK_STATUS" != "stopped" ];
do
  sleep 10;
  echo "waiting for replication task to stop"
  REPLICATION_TASK_STATUS=$(aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" | jq -r  '.[].ReplicationTaskStatus')
  echo "$REPLICATION_TASK_STATUS"
done

echo "removing replicaion task"
aws dms delete-replication-task --replication-task-arn ${DMS_TASK_ARN1}

REPLICATION_TASK_STATUS="deleting"
while [ "$REPLICATION_TASK_STATUS" = "deleting" ];
do
  sleep 10;
  echo "waiting for replication task to be deleted"
  REPLICATION_TASK_STATUS=$(aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" | jq -r  '.[].ReplicationTaskStatus')
  echo "$REPLICATION_TASK_STATUS"
done


#remove endpoints
aws dms delete-endpoint --endpoint-arn $DB_TGT_ENDPOINT
aws dms delete-endpoint --endpoint-arn $DB_SRC_ENDPOINT

#dropping database schema and data
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c "drop schema data_mart cascade;"
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c "drop schema data_mart_new cascade;"
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c "drop schema partman cascade;"

#delete DMS instance
aws cloudformation delete-stack --stack-name DMSRepforBlog

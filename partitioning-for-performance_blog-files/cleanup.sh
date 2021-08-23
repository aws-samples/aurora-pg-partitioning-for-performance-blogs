#!/bin/bash
export AURORA_DB_CFSTACK_NAME="mydb"

SrcRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')

export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"


export AWSDMS_CFSTACK_NAME="DMSRepforBlog"
export AWS_DEFAULT_REGION="us-east-1"

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

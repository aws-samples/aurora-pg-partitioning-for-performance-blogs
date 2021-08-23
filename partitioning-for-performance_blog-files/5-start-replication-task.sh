#/bin/bash

export AWSDMS_CFSTACK_NAME="DMSRepforBlog"

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


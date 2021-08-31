#/bin/bash

export AWSDMS_CFSTACK_NAME="DMSRepforBlog"

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

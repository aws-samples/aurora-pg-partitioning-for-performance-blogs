#/bin/bash

export AURORA_DB_CFSTACK_NAME="mydb"
export AWS_DEFAULT_REGION="us-east-1"
echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

echo "Enabling logical replication..."
CLUSTER_PARAM_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterParameterGroup')
DB_INSTANCE_IDENTIFIER=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterMembers[].DBInstanceIdentifier')

aws rds modify-db-cluster-parameter-group --db-cluster-parameter-group-name $CLUSTER_PARAM_GROUP --parameters "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot"

aws rds reboot-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER

SrcRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')
TgtRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')

echo "RDS Source endpoint:" $SrcRDSEndPoint
echo "RDS Destination endpoint" $TgtRDSEndPoint

SubnetID1=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SubnetID1") | .OutputValue')
SubnetID2=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SubnetID2") | .OutputValue')

echo "DB subnet 1:" $SubnetID1
echo "DB subnet 2:" $SubnetID2

RepSecurityGroup=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSSecurityGrp") | .OutputValue')

echo "Security group:" $RepSecurityGroup
 
export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"


aws cloudformation create-stack --stack-name DMSRepforBlog --template-body file://dms.yaml --parameters ParameterKey=RepAllocatedStorage,ParameterValue=100 ParameterKey=RepMultiAZ,ParameterValue=false ParameterKey=RepSecurityGroup,ParameterValue=$RepSecurityGroup ParameterKey=ReplInstanceType,ParameterValue=dms.t3.medium ParameterKey=SrcDBUsername,ParameterValue=$SrcDBUsername ParameterKey=SrcDBPassword,ParameterValue=$SrcDBPassword ParameterKey=SrcDatabaseConnection,ParameterValue=$SrcRDSEndPoint ParameterKey=SrcEngineType,ParameterValue=aurora-postgresql ParameterKey=Subnets,ParameterValue="$SubnetID1 \, $SubnetID2" ParameterKey=TgtDBUsername,ParameterValue=$TgtDBUsername ParameterKey=TgtDBPassword,ParameterValue=$TgtDBPassword ParameterKey=TgtDatabaseConnection,ParameterValue=$TgtRDSEndPoint ParameterKey=TgtEngineType,ParameterValue=aurora-postgresql

STACK_STATUS=""
while [ "$STACK_STATUS" != "CREATE_COMPLETE" ];
do
  echo "waiting for stack to complete"
  STACK_STATUS=$(aws cloudformation describe-stacks --stack-name DMSRepforBlog | jq -r '.Stacks[].StackStatus') 
  echo "$STACK_STATUS"
   sleep 60;
done

export AWSDMS_CFSTACK_NAME="DMSRepforBlog"

#Set variable to replication instance arn
DMSREP_INSTANCE_ARN=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ReplicationInstanceArn") | .OutputValue')

#source and target endpoint
DB_TGT_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="TgtEndpointArn") | .OutputValue')
DB_SRC_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="SrcEndpointArn") | .OutputValue')

echo "DB target endpoint:" $DB_TGT_ENDPOINT
echo "DB source endpoint:" $DB_SRC_ENDPOINT
echo "DMS instance ARN:" $DMSREP_INSTANCE_ARN


aws dms test-connection --replication-instance-arn ${DMSREP_INSTANCE_ARN} --endpoint-arn ${DB_SRC_ENDPOINT}
aws dms test-connection --replication-instance-arn ${DMSREP_INSTANCE_ARN} --endpoint-arn ${DB_TGT_ENDPOINT}

CONNECTION_STATUS=""
while [ "$CONNECTION_STATUS" != "successful" ];
do
  echo "waiting for connection to be successful"
  CONNECTION_STATUS=$(aws dms describe-connections --filter Name=endpoint-arn,Values=${DB_SRC_ENDPOINT} Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN}  | jq -r '.Connections[].Status')
  echo "Connection status is:" $CONNECTION_STATUS
  sleep 10;
done

CONNECTION_STATUS=""
while [ "$CONNECTION_STATUS" != "successful" ];
do
  echo "waiting for connection to be successful"
  CONNECTION_STATUS=$(aws dms describe-connections --filter Name=endpoint-arn,Values=${DB_TGT_ENDPOINT} Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN}  | jq -r '.Connections[].Status')
  echo "Connection status is:" $CONNECTION_STATUS
  sleep 10;
done


export task_identifier=dms-task-partitioning

aws dms create-replication-task --replication-task-identifier ${task_identifier} --source-endpoint-arn ${DB_SRC_ENDPOINT} --target-endpoint-arn ${DB_TGT_ENDPOINT} --replication-instance-arn ${DMSREP_INSTANCE_ARN} --migration-type full-load-and-cdc --table-mappings 'file://tablemapping.json' --replication-task-settings 'file://tasksetting.json'


DMS_TASK_ARN1=$(aws dms describe-replication-tasks | jq -r  '.ReplicationTasks[]|select(.ReplicationTaskIdentifier=="dms-task-partitioning")|.ReplicationTaskArn')
echo "Replication task ARN:" $DMS_TASK_ARN1
#aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" --output table

#######
#REPLICATION_TASK_STATUS=""
#while [ "$REPLICATION_TASK_STATUS" != "ready" ];
#do
#  echo "waiting for replication task to be created"
#  REPLICATION_TASK_STATUS=$(aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" | jq -r  '.[].ReplicationTaskStatus')
#  echo "Replication task status is": $REPLICATION_TASK_STATUS
#  sleep 10;
#done

#echo "Start replication task"

#aws dms start-replication-task --replication-task-arn ${DMS_TASK_ARN1} --start-replication-task-type start-replication
#
#echo "Waiting on replication task to start"
#sleep 60;

#echo "Check status of replication task"

#aws dms describe-replication-tasks --filters Name=replication-instance-arn,Values=${DMSREP_INSTANCE_ARN} --query "ReplicationTasks[:].{ReplicationTaskIdentifier:ReplicationTaskIdentifier,ReplicationTaskArn:ReplicationTaskArn,ReplicationTaskStatus:Status,ReplicationTFullLoadPercent:ReplicationTaskStats.FullLoadProgressPercent}" --output table

#####

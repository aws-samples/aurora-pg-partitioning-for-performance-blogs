#!/bin/bash

help () {

printf "Script: 04-setup_dms.sh\n"
printf "Usage: 04-setup_dms.sh [ -s ] [ -r ] [ -d ] [ -h ] \n"
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

echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME


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


aws cloudformation create-stack --stack-name $AWSDMS_CFSTACK_NAME --template-body file://dms.yaml --parameters ParameterKey=RepAllocatedStorage,ParameterValue=100 ParameterKey=RepMultiAZ,ParameterValue=false ParameterKey=RepSecurityGroup,ParameterValue=$RepSecurityGroup ParameterKey=ReplInstanceType,ParameterValue=dms.t3.medium ParameterKey=SrcDBUsername,ParameterValue=$SrcDBUsername ParameterKey=SrcDBPassword,ParameterValue=$SrcDBPassword ParameterKey=SrcDatabaseConnection,ParameterValue=$SrcRDSEndPoint ParameterKey=SrcEngineType,ParameterValue=aurora-postgresql ParameterKey=Subnets,ParameterValue="$SubnetID1 \, $SubnetID2" ParameterKey=TgtDBUsername,ParameterValue=$TgtDBUsername ParameterKey=TgtDBPassword,ParameterValue=$TgtDBPassword ParameterKey=TgtDatabaseConnection,ParameterValue=$TgtRDSEndPoint ParameterKey=TgtEngineType,ParameterValue=aurora-postgresql

STACK_STATUS=""
while [ "$STACK_STATUS" != "CREATE_COMPLETE" ];
do
  echo "waiting for stack to complete"
  STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $AWSDMS_CFSTACK_NAME | jq -r '.Stacks[].StackStatus') 
  echo "$STACK_STATUS"
   sleep 60;
done

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

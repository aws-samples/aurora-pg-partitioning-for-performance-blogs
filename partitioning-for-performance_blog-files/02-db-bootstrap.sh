#!/bin/bash

help () {

printf "Script: 02-db-bootstrap.sh\n"
printf "Usage: 02-db-bootstrap.sh [ -s ] [ -r ] [ -d ]\n"
printf " -- \nWhere: \n"
printf "   -s  The inital AWS Stack name which is to create the vpc, subnet, and Aurora cluster. \n"
printf "       Whatever value is set when running script 01-install_prereq.sh is what should be retained\n"
printf "       for the rest of the demo scripts. This flag can be avoided if AURORA_DB_CFSTACK_NAME is \n"
printf "       set as an environment variable. \n"
printf "   -r  The AWS Region we're running this demo in. This setting needs to stay the same across all scripts run.\n"
printf "       Using this flag can be avoided if AWS_DEFAULT_REGION is set as an environment variable where running this script\n"
printf "   -h  show help page.\n"

}

while getopts 's:r:h' flag; do
  case "${flag}" in
    s) AURORA_DB_CFSTACK_NAME="${OPTARG}" ;;
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

## Mainline


echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

SrcRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')
TgtRDSEndPoint=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RDSEndPoint") | .OutputValue')
ClusterName=$(aws cloudformation describe-stacks --stack-name $AURORA_DB_CFSTACK_NAME | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ClusterName") | .OutputValue')

echo "RDS Source endpoint:" $SrcRDSEndPoint
echo "RDS Destination endpoint" $TgtRDSEndPoint
echo "RDS Cluster name" $ClusterName


export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"

 

SYNC_STATUS=""
while [ "$SYNC_STATUS" != "in-sync" ];
do
  echo "waiting for database to restart "
  SYNC_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier $ClusterName | jq -r '.DBClusters[].DBClusterMembers[].DBClusterParameterGroupStatus')
  echo "Database Sync status is:" $SYNC_STATUS
  sleep 10;
done


sleep 2
echo "Creating database schema"

psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f schema.sql 

echo "Loading sample data"
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"\copy data_mart.organization(org_name) from 'org.csv'"                 
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"\copy data_mart.events (operation,value,event_type,org_id,created_at) from 'events.csv' delimiter ',';"

echo "Running pg_dump to extract pre and post data schema dedination"

pg_dump postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -t data_mart.events -s -U postgres --section=pre-data > data_mart.events-pre-schema.sql  
pg_dump postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -t data_mart.events -s -U postgres --section=post-data > data_mart.events-post-schema.sql 

echo "Editing dump file to convert table defination from non-partitioned to partitioned"

sed -i 's/data_mart/data_mart_new/g' data_mart.events-pre-schema.sql 


var1="CONSTRAINT ck_valid_operation CHECK (((operation = 'C'::bpchar) OR (operation = 'D'::bpchar)))"
line=(`grep -n  "$var1" data_mart.events-pre-schema.sql | awk -F ':' '{print $1}'`)

line=$((line+1))
substitute="   )PARTITION BY RANGE (created_at);"
sed -i "${line}s/.*/$substitute/"  data_mart.events-pre-schema.sql

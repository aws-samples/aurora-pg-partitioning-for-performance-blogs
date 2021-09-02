#!/bin/bash

help () {

printf "Script: 03-create-partitoned-table.sh\n"
printf "Usage: 03-create-partitoned-table.sh [ -s ] [ -r ] [ -h ] \n"
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

echo "RDS Source endpoint:" $SrcRDSEndPoint
echo "RDS Destination endpoint" $TgtRDSEndPoint


export SrcDBUsername="pgadmin"
export SrcDBPassword="auradmin"
export TgtDBUsername="pgadmin"
export TgtDBPassword="auradmin"



# install schema in data_mart_new schema

psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"create schema data_mart_new;"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f data_mart.events-pre-schema.sql

echo "Using pgpartman to create partitioned tables"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"CREATE SCHEMA partman;CREATE EXTENSION pg_partman WITH SCHEMA partman;"
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"SELECT partman.create_parent( p_parent_table => 'data_mart_new.events', \
p_control => 'created_at', \
p_type => 'native', \
p_interval=> 'monthly', \
p_premake => 12);"


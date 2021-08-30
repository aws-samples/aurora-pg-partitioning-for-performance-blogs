export AURORA_DB_CFSTACK_NAME="mydb"
export AWS_DEFAULT_REGION="us-east-1"
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


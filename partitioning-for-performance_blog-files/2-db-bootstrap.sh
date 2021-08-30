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

sleep 2
echo "\nCreating database schema"

psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f schema.sql 

echo "loading data"
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"\copy data_mart.organization(org_name) from 'org.csv'"                 
psql  postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -c"\copy data_mart.events (operation,value,event_type,org_id,created_at) from 'events.csv' delimiter ',';"

echo "Running pg_dump to extra pre and post data schema dedination"

pg_dump postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -t data_mart.events -s -U postgres --section=pre-data > data_mart.events-pre-schema.sql  
pg_dump postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -t data_mart.events -s -U postgres --section=post-data > data_mart.events-post-schema.sql 

echo "Editing dump file to convert table defination from non-partitioned to partitioned"
sed -i 's/data_mart/data_mart_new/g' data_mart.events-pre-schema.sql 


var1="CONSTRAINT ck_valid_operation CHECK (((operation = 'C'::bpchar) OR (operation = 'D'::bpchar)))"
line=(`grep -n  "$var1" data_mart.events-pre-schema.sql | awk -F ':' '{print $1}'`)

line=$((line+1))
substitute="   )PARTITION BY RANGE (created_at);"
sed -i "${line}s/.*/$substitute/"  data_mart.events-pre-schema.sql

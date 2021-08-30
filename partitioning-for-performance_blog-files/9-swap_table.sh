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

#create helper function to move child table
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f swap_table_function.sql
psql postgres://$SrcDBUsername:$SrcDBPassword@$SrcRDSEndPoint -f swap_table.sql

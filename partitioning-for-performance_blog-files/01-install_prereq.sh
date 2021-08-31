#/bin/bash
sudo tee /etc/yum.repos.d/pgdg.repo<<EOF
[pgdg12]
name=PostgreSQL 12 for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0
EOF
sudo yum makecache

sudo yum install jq -y
sudo yum install postgresql12 -y

echo "Enabling logical replication for your PostgeSQL Database"
 
export AURORA_DB_CFSTACK_NAME="mydb"
export AWS_DEFAULT_REGION="us-east-1"
echo "DB stack name is:" $AURORA_DB_CFSTACK_NAME

echo "Enabling logical replication..."
CLUSTER_PARAM_GROUP=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterParameterGroup')
DB_INSTANCE_IDENTIFIER=$(aws rds describe-db-clusters --db-cluster-identifier "aurora-db" | jq -r '.DBClusters[].DBClusterMembers[].DBInstanceIdentifier')

aws rds modify-db-cluster-parameter-group --db-cluster-parameter-group-name $CLUSTER_PARAM_GROUP --parameters "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot"

aws rds reboot-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER

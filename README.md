# Partitioning for Performance


## Overview
Purpose of this lab is provide you step-by-step guide instructions to split large table in PostgreSQL into multiple manageable partitioned tables with minimal downtime.

Solution utilizes AWS Database Migration Service (DMS) to read data from source (non-partitioned table) and replicate into partitioned table in the same database.


## Setup Instructions:

 1. Run CloudFormation (CF) db.yaml to create Aurora Database in private VPC,
    following resources will be created.
	
	- VPC 
	- Private/Public subnet and related resources 
	- Aurora DB in Private subnet
2. Connect to Cloud 9 instance, created by CF
3. Checkout this repo in Cloud 9 to get script and data for the demo
4. Run scripts provided to simulate end to end process to split table into partitioned table

	
Export following environment variable, alternatively you can pass argument to the script

```sh
export AURORA_DB_CFSTACK_NAME=mydb
export AWS_DEFAULT_REGION=us-east-1
```


Step1:    This will install psql client and jq
```sh
bash 01-install_prereq.sh 
```
Step2:   This script will create database schema data_mart with two table, events and organization and load sample data. events table will be large table, we will be partitioning.
```sh
bash 02-db-bootstrap.sh 
```
Step3:  This script will create Partitioned table under new schema data_mart_new
```sh
bash 03-create-partitoned-table.sh
``` 

Step4: This will setup DMS instance/configure endpoint and create replication task
```sh
AWSDMS_CFSTACK_NAME=mydms; # this is the name of the DMS stack
bash 04-setup_dms.sh
```
Step5: This script will start replication task to move data from data_mart.events to data_mart_new.events ( which is partitioned table )
```sh
bash 05-start-replication-task.sh
```
Step6: This script will display count of data from source and destination table
```sh
bash 06-verify-count.sh 
```
Step7: This script will create post full load index creation on a partitioned table
```sh
bash 07-create-index.sh
```
At this point, you have data in sync between source and destination schema. Next you need to swap the table to switch to Partitioned table. (this process will require brief outage)

***Ensure application writing to this table is down before the next step**

Step8: Once replication is caught up, stop replication task
```sh
bash 08-stop-replication-task.sh
```
Step9: Use this script to swap table
```sh
bash 09-swap_table.sh 
```
Step10:  Use this script to disable logical replication
```sh
bash 10-disable-logical-replication.sh
```
## Cleanup
Step1:  Cloud9, run 11-cleanup.sh to remove DMS instance and related resources
```sh
./11-cleanup.sh
```
Step2:  On CloudFormation console, delete database cloudformation to remove database and other VPC related objects

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.


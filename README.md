## 


Setup Instructions:

1. Run CloudFormation db.yaml to create Aurora database in private VPC
2. Go to output of Cloudformation and click to Connect to Cloud 9 instance
3. Checkout this repo in Cloud 9 to get script and data for the demo
4. Run the following script in this order to setup sample database and partition the table

    1. 1-install_prereq.sh: This will install psql client and jq
    2. 2-db-bootstrap.sh: This script will install schema and load sample data
    3. 3-create-partitoned-table.sh:  This script will create Partitioned table in new schema (data_mart_new)
    4. 4-setup_dms.sh: This will setup DMS instance/configure endpoint and create a task
    5. 5-start-replication-task.sh: This script will start replication task to move data from data_mart.events to data_mart_new.events ( which is partitioned table )
    6. 6-verify-count.sh: This script will display count of data from source and destination table
    7. 7-create-index.sh: This script will create post full load index creation 

    At this point, you have data in sync between source and destination schema. Next you need to swap the table to switch to Partitioned table. (this process will require brief outage)

    Ensure application writing to this table is down 

1. 8-stop-replication-task.sh: once replication is caught up, stop replication task
2. 9-swap_table.sh : use this script to swap table 
3. 10-disable-logical-replication.s : use this script to disable logical replication.

Cleanup:

1. on Cloud9, run cleanup.sh to remove dms instance and cloudformation
2. on Cloudformation console, delete database cloudformation to remove database and other VPC related objects


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.


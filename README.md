## 


1. Run CF to create Aurora database in private database
2. Connect to Cloud 9 instance
3. Checkout the repo in Cloud 9 to get script and data for the demo
4. Run the following script
    1. 1-install_prereq.sh: This will install psql client and jq
    2. 2-setup_dms.sh: this will setup DMS instance/configure endpoint and create a task
    3. 3-db-bootstrap.sh: This script will install schema and load sample data
       On o
    4. 4-create-partitoned-table.sh: This script will create Partitioned table in new schema (data_mart_new)
    5.  5-start-replication-task.sh: This script will start replication task to move data from data_mart.events to data_mart_new.events ( which is partitioned table )
    6.  6-create-index.sh: This script will create post full load index creation 
    7. 7-verify-count.sh: This script will display count of data from source and destination table

Cleanup:

1. on Cloud9, run cleanup.sh to remove dms instance and cloudformation
2. on CF console, delete database cloudfomration to remove database and other VPC related objects



Be sure to:

* Change the title in this README
* Edit your repository description on GitHub

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.


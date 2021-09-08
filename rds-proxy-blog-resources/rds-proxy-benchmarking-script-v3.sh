#!/bin/bash

source rdsproxy.env

pg_conn_rdsproxy="rdsproxy-reader-test-1a-read-only.endpoint.proxy-xxxxxx.us-east-1.rds.amazonaws.com"
pg_conn_apg_direct="apg-labs-test-pglogical-clustera.cluster-ro-xxxxxx.us-east-1.rds.amazonaws.com"

cluster_ident="apg-labs-test-pglogical-clustera"

threads=10

sleep_time=5

runtime_per_thread=60

logdir="rdsproxy_benchmark_logs"

int_runtime="30 minutes"
intendtime=$(date -ud "$int_runtime" +%s)
endtime=$(date -ud "$total_runtime" +%s)

function workload {
  for t in {1..10}
    do
        #pgbench_cmd
        NOW=$(date +"%m-%d-%Y-%R")
        touch $logdir/$NOW-Run-$t.log
        printf "Running $t in current loop $NOW\n"
	printf "Using db endpoint $1\n"
        nohup pgbench -h $1 -U postgres -d postgres -c 100 -n --select-only -T 600 -C -P 1 > $logdir/$NOW-Run-$t.log 2>&1 &

  sleep $sleep_time
  done
  echo "Sleeping 50 seconds in between runs"
  sleep 50
}

#---mainline

mkdir -p $logdir

  #printf "Waiting 10 minutes to get started\n"

  #sleep 600

  printf "01. Running read only workload against APG read endpoint directly\n"
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_apg_direct
  done
  # failover instance
  printf "02. Failing over APG instance\n"

  aws rds failover-db-cluster --db-cluster-identifier $cluster_ident

  # run workload again
    printf "03. Re-running read only workload against APG read endpoint directly\n"
  intendtime=$(date -ud "$int_runtime" +%s)
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_apg_direct
  done

  # create read replica
  printf "04. Creating a read-replica to see what happens to traffic (APG read-only-endpoint)\n"

  aws rds create-db-instance --db-instance-identifier instance-5 --db-cluster-identifier $cluster_ident --engine aurora-postgresql --db-instance-class db.r5.large

  # run workload again
    printf "05. Re-running read only workload against APG after creating read replica (APG read-only-endpoint)\n"
  intendtime=$(date -ud "$int_runtime" +%s)
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_apg_direct
  done

  # dropping the read replica

  printf "Dropping the read replica instance-5 (APG read-only-endpoint)\n"

  aws rds delete-db-instance --db-instance-identifier instance-5

  printf "07. Sleeping for 10 minutes\n"

  sleep 600

  # --- switch to RDS proxy endpoint
  printf "08. Running read only workload against RDS proxy read endpoint (rds proxy endpoint)\n"
  intendtime=$(date -ud "$int_runtime" +%s)
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_rdsproxy
  done

  # failover
  printf "09. Failing over APG instance (rds proxy endpoint)\n"

  aws rds failover-db-cluster --db-cluster-identifier $cluster_ident

  # run workload again
    printf "10. Re-running read only workload against APG read endpoint directly (rds proxy endpoint)\n"
  intendtime=$(date -ud "$int_runtime" +%s)
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_rdsproxy
  done

  # create read replica
  printf "11. Creating a read-replica to see what happens to traffic (rds proxy endpoint)\n"

  aws rds create-db-instance --db-instance-identifier instance-6 --db-cluster-identifier $cluster_ident --engine aurora-postgresql --db-instance-class db.r5.large

  # run workload again
  printf "12. Re-running read only workload against APG after creating read replica (rds proxy-endpoint)\n"
  intendtime=$(date -ud "$int_runtime" +%s)
  while [[ $(date -u +%s) -le $intendtime ]]
  do
    workload $pg_conn_rdsproxy
  done

  # dropping the read replica

  printf "13. Dropping Read Replica instance-6 (rds proxy endpoint)\n"

  aws rds delete-db-instance --db-instance-identifier instance-6


  printf "Benchmarking Finished \n"

#!/bin/bash
#
cd /tmp
source ./local-kub-env.sh
bash replication.sh \
    --remove local \
    --primary-host $ML_LOCAL_HOST \
    --secondary-host $ML_FOREIGN_HOST \
    --database "$ML_DATABASE" \
    --primary-cluster $ML_LOCAL_CLUSTER_NAME \
    --secondary-cluster $ML_FOREIGN_CLUSTER_NAME

bash replication.sh \
    --remove foreign \
    --primary-host $ML_LOCAL_HOST \
    --secondary-host $ML_FOREIGN_HOST \
    --database "$ML_DATABASE" \
    --primary-cluster $ML_LOCAL_CLUSTER_NAME \
    --secondary-cluster $ML_FOREIGN_CLUSTER_NAME

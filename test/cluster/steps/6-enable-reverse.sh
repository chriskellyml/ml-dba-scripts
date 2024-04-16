#!/bin/bash

cd /tmp
source ./local-kub-env.sh
bash replication.sh \
    --enable-forward \
    --primary-host $ML_FOREIGN_HOST \
    --secondary-host $ML_LOCAL_HOST \
    --username $ML_USERNAME \
    --password $ML_PASSWORD \
    --database "$ML_DATABASE" \
    --primary-cluster $ML_FOREIGN_CLUSTER_NAME \
    --secondary-cluster $ML_LOCAL_CLUSTER_NAME

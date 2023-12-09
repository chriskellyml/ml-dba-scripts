#!/bin/bash

usage() {
    echo "USAGE: ./$0 <ACTION> [OPTIONS]"
}

main() {
    PROTOCOL=$1
    MASTER_HOST=$2
    REPLICA_HOST=$3
    USERNAME=$4
    PASSWORD=$5
    
    MASTER_ADMIN=$USERNAME
    MASTER_PASS=$PASSWORD

    REPLICA_ADMIN=$USERNAME
    REPLICA_PASS=$PASSWORD

    # Make sure you have SSM port forwarded the primary/local cluster to 8002, and the foreign/replica to 9002 via ssm-tunnel-(primary|replica)bash
    echo "Retrieving primary/local cluster properties"
    PRIMARY_PROPERTIES=$(getClusterProperties $MASTER_HOST $MASTER_ADMIN $MASTER_PASS $PROTOCOL)
    echo "Retrieving replica/foreign cluster properties"
    REPLICA_PROPERTIES=$(getClusterProperties $REPLICA_HOST $REPLICA_ADMIN $REPLICA_PASS $PROTOCOL)

    REPLICA_CLUSTER_NAME=$(echo $REPLICA_PROPERTIES | grep -o '"cluster-name":"[^"]*"' | cut -d: -f2 | tr -d '"')
    echo "Replica/foreign cluster name is $REPLICA_CLUSTER_NAME"

    NEW_PRIMARY=$(echo $PRIMARY_PROPERTIES | sed 's/"language-baseline":"[^"]*",//g')
    NEW_REPLICA=$(echo $REPLICA_PROPERTIES | sed 's/"language-baseline":"[^"]*",//g')

    # Tell the primary/local cluster to couple with the foreign/replica
    echo "Coupling primary to replica"
    coupleClusters $MASTER_HOST $MASTER_ADMIN $MASTER_PASS $PROTOCOL $NEW_REPLICA
    sleep 15

    # Tell the foreign/replica cluster to couple with the primary/local
    echo "Coupling replica to primary"
    coupleClusters $REPLICA_HOST $REPLICA_ADMIN $REPLICA_PASS $PROTOCOL $NEW_PRIMARY
    sleep 15

    # Test the bootstrap status of the coupling between the two clusters on the primary/master
    echo "Fetching coupling bootstrap status..."
    BOOTSTATUS=$(getBootStatus $MASTER_HOST $MASTER_ADMIN $MASTER_PASS $REPLICA_CLUSTER_NAME $PROTOCOL)
    sleep 10
    if [ ! -z "$(which python)" ];then
        # Easy way to get the value from the json without jq is to use python
        BOOTSTRAP_STATUS=$(echo $BOOTSTATUS | python -c "import sys, json; print(json.loads(sys.stdin.read())['foreign-cluster-status']['foreign-status-properties']['is-bootstrapped'])")
        echo "Bootstrap status is: $BOOTSTRAP_STATUS"
    else
        # If you don't have python, you can use grep and cut but results may vary
        BOOTSTRAP_STATUS=$(echo $BOOTSTATUS | grep -o '"is-bootstrapped":[^,]*' | cut -d: -f2)
        echo "Bootstrap status is: $BOOTSTRAP_STATUS"
    fi
}

getBootStatus() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local REPLICA_CLUSTER_NAME=$4
    local PROTOCOL=$5
    curl -s \
        --anyauth --user $USER:$PASS \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters/${REPLICA_CLUSTER_NAME}?format=json&view=status"
}

getClusterProperties() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local PROTOCOL=$4
    curl -s \
        --anyauth --user $USER:$PASS \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/properties?format=json"
}

coupleClusters() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local PROTOCOL=$4
    local OTHER=$5
    curl -s -X POST  \
        --anyauth --user $ADMIN:$PASS \
        --header "Content-Type:application/json" \
        -d "$OTHER" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters?format=json" 
}

main "$@"

#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/util.sh"

usage() {
    echo "source my-custom-env.sh"
    echo "USAGE: ./$0 --run"
}

main() {
    init

    # Make sure you have SSM port forwarded the primary/local cluster to 8002, and the foreign/replica to 9002 via ssm-tunnel-(primary|replica)bash
    echo "Retrieving primary/local cluster properties"
    PRIMARY_PROPERTIES=$(getClusterProperties \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD $ML_PROTOCOL \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD \
    )
    echo "Retrieving replica/foreign cluster properties"
    FOREIGN_PROPERTIES=$(getClusterProperties \
        $ML_FOREIGN_HOST $ML_FOREIGN_ADMIN $ML_FOREIGN_PASSWORD $ML_PROTOCOL \
        $ML_FOREIGN_CERT_PATH $ML_LOCAL_CERT_PASSWORD \
    )

    FOREIGN_CLUSTER_NAME=$(echo $FOREIGN_PROPERTIES | grep -o '"cluster-name":"[^"]*"' | cut -d: -f2 | tr -d '"')
    echo "Replica/foreign cluster name is $FOREIGN_CLUSTER_NAME"

    NEW_PRIMARY=$(echo $PRIMARY_PROPERTIES | sed 's/"language-baseline":"[^"]*",//g')
    NEW_REPLICA=$(echo $FOREIGN_PROPERTIES | sed 's/"language-baseline":"[^"]*",//g')

    # Tell the primary/local cluster to couple with the foreign/replica
    echo "Coupling primary to replica"
    coupleClusters \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD \
        $ML_PROTOCOL $NEW_REPLICA \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD
    # FIXME: Poll server on port 7997 until it's up
    sleep 15

    # Tell the foreign/replica cluster to couple with the primary/local
    echo "Coupling replica to primary"
    coupleClusters \
        $ML_FOREIGN_HOST $ML_FOREIGN_ADMIN $ML_FOREIGN_PASSWORD \
        $ML_PROTOCOL $NEW_PRIMARY \
        $ML_FOREIGN_CERT_PATH $ML_FOREIGN_CERT_PASSWORD
    # FIXME: Poll server on port 7997 until it's up
    sleep 15

    # Test the bootstrap status of the coupling between the two clusters on the primary/master
    echo "Fetching coupling bootstrap status..."
    BOOTSTATUS=$(getBootStatus \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD \
        $FOREIGN_CLUSTER_NAME $ML_PROTOCOL \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD \
    )
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

getClusterProperties() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local PROTOCOL=$4
    local CERT_PATH=$5
    local CERT_PASS=$6
    # Set up cert options
    local certOpts=()
    if [ -n "$CERT_PATH" ];then
        certOpts=(--cert-type p12 --cert "$CERT_PATH:$CERT_PASS")
    fi
    curl -s \
        --anyauth --user $USER:$PASS ${certOpts[@]} \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/properties?format=json"
}

coupleClusters() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local PROTOCOL=$4
    local OTHER=$5
    local CERT_PATH=$6
    local CERT_PASS=$7
    # Set up cert options
    local certOpts=()
    if [ -n "$CERT_PATH" ];then
        certOpts=(--cert-type p12 --cert "$CERT_PATH:$CERT_PASS")
    fi
    curl -s -X POST  \
        --anyauth --user $ADMIN:$PASS ${certOpts[@]}\ 
        --header "Content-Type:application/json" \
        -d "$OTHER" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters?format=json" 
}

getBootStatus() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local FOREIGN_CLUSTER_NAME=$4
    local PROTOCOL=$5
    local CERT_PATH=$6
    local CERT_PASS=$7
    # Set up cert options
    local certOpts=()
    if [ -n "$CERT_PATH" ];then
        certOpts=(--cert-type p12 --cert "$CERT_PATH:$CERT_PASS")
    fi
    curl -s \
        --anyauth --user $USER:$PASS  ${certOpts[@]} \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters/${FOREIGN_CLUSTER_NAME}?format=json&view=status"
}


init() {
    mandatoryEnv \
        "ML_PROTOCOL" \
        "ML_LOCAL_ADMIN" "ML_LOCAL_PASSWORD" "ML_LOCAL_CLUSTER_HOST" \
        "ML_LOCAL_CERT_PATH" "ML_LOCAL_CERT_PASSWORD" \
        "ML_FOREIGN_ADMIN" "ML_FOREIGN_PASSWORD" "ML_FOREIGN_CLUSTER_HOST" \
        "ML_FOREIGN_CERT_PATH" "ML_FOREIGN_CERT_PASSWORD"
}

if [[ "$1" == "--run" ]]; then
    main
else
    usage
fi


#!/bin/bash
#
set -e

source "$(dirname "${BASH_SOURCE[0]}")/util.sh"

usage() {
    echo "source my-custom-env.sh"
    echo "USAGE: ./$0 --run"
}

main() {
    init

    # Make sure you have SSM port forwarded the primary/local cluster to 8002, and the foreign/replica to 9002 via ssm-tunnel-(primary|replica)bash
    echo "Retrieving primary/local cluster properties"
    LOCAL_PROPERTIES=$(getClusterProperties \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD $ML_LOCAL_PROTOCOL \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD \
    )
    echo "Retrieving replica/foreign cluster properties"
    FOREIGN_PROPERTIES=$(getClusterProperties \
        $ML_FOREIGN_HOST $ML_FOREIGN_ADMIN $ML_FOREIGN_PASSWORD $ML_FOREIGN_PROTOCOL \
        $ML_FOREIGN_CERT_PATH $ML_LOCAL_CERT_PASSWORD \
    )

    FOREIGN_CLUSTER_NAME=$(echo $FOREIGN_PROPERTIES | grep -o '"cluster-name":"[^"]*"' | cut -d: -f2 | tr -d '"')
    echo "Replica/foreign cluster name is $FOREIGN_CLUSTER_NAME"

    NEW_PRIMARY="$(echo "$LOCAL_PROPERTIES" | awk 'BEGIN{RS=","; ORS=""; first=1} !/"language-baseline":/{if (!first) printf(","); printf("%s", $0); first=0} END{print ""}')}"
    NEW_REPLICA="$(echo "$FOREIGN_PROPERTIES" | awk 'BEGIN{RS=","; ORS=""; first=1} !/"language-baseline":/{if (!first) printf(","); printf("%s", $0); first=0} END{print ""}')}"

    # Tell the primary/local cluster to couple with the foreign/replica
    echo "Coupling primary to replica"
    coupleClusters \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD \
        $ML_LOCAL_PROTOCOL  \
        "$NEW_REPLICA" \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD
    # FIXME: Poll server on port 7997 until it's up

    echo ""
    echo "Waiting 15 seconds to allow time for local to come back up..."
    sleep 15

    # Tell the foreign/replica cluster to couple with the primary/local
    echo "Coupling replica to primary"
    coupleClusters \
        $ML_FOREIGN_HOST $ML_FOREIGN_ADMIN $ML_FOREIGN_PASSWORD \
        $ML_FOREIGN_PROTOCOL  \
        "$NEW_PRIMARY" \
        $ML_FOREIGN_CERT_PATH $ML_FOREIGN_CERT_PASSWORD
    # FIXME: Poll server on port 7997 until it's up
    echo ""
    echo "Waiting 15 seconds to allow time for foreign to come back up..."
    sleep 15


    # Test the bootstrap status of the coupling between the two clusters on the primary/master
    echo "Fetching coupling bootstrap status..."
    BOOTSTATUS="$(getBootStatus \
        $ML_LOCAL_HOST $ML_LOCAL_ADMIN $ML_LOCAL_PASSWORD \
        $FOREIGN_CLUSTER_NAME $ML_LOCAL_PROTOCOL \
        $ML_LOCAL_CERT_PATH $ML_LOCAL_CERT_PASSWORD
    )"

    local IS_BOOTSTRAPPED=$(echo "$BOOTSTATUS" | awk -F'"is-bootstrapped":' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    echo "Is bootstrapped: $IS_BOOTSTRAPPED"
}

# TODO: reuse util.sh httpPOST and httpGET functions
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
        --anyauth --user "$USER:$PASS" ${certOpts[@]} \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/properties?format=json"
}

coupleClusters() {
    local HOST=$1
    local USER=$2
    local PASS=$3
    local PROTOCOL=$4
    local PAYLOAD="$5"
    local CERT_PATH=$6
    local CERT_PASS=$7

    # Set up cert options
    local certOpts=()
    if [ -n "$CERT_PATH" ];then
        certOpts=(--cert-type p12 --cert "$CERT_PATH:$CERT_PASS")
    fi

    #set -o xtrace
    curl -s -X POST  \
        --anyauth --user "$USER:$PASS" ${certOpts[@]} \
        --header "Content-Type:application/json" \
        -d "$PAYLOAD" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters?format=json"
    #set +o xtrace
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
        --anyauth --user "$USER:$PASS" ${certOpts[@]} \
        --header "Content-Type:application/json" \
        -k "$PROTOCOL://$HOST:8002/manage/v2/clusters/${FOREIGN_CLUSTER_NAME}?format=json&view=status"
}


init() {
    mandatoryEnv \
        "ML_LOCAL_PROTOCOL" "ML_FOREIGN_PROTOCOL" \
        "ML_LOCAL_ADMIN" "ML_LOCAL_PASSWORD" "ML_LOCAL_HOST" \
        "ML_FOREIGN_ADMIN" "ML_FOREIGN_PASSWORD" "ML_FOREIGN_HOST"
}

if [[ "$1" == "--run" ]]; then
    main
else
    usage
fi

#!/bin/bash

source ./util.sh

usage() {
    echo "USAGE: ./$0 <ACTION> [OPTIONS]

  ACTION(s):
      --remove            Removes replication on primary or secondary cluster
      --enable-forward    Enables replication from primary to secondary
      --enable-reverse    Enables replication from secondary to primary

  OPTIONS
      --databases         Database to act on.
      --username          Username if no $USER variable is defined.
      --password          Password if no $PASS variable is defined.
      --primary-host      Provide hostname for primary cluster.
      --secondary-host    Provide hostname for secondary cluster.
      --help              Show this help message.
    "
}

main() {
    local runId=$(date +%s)
    processArgs $@
    # showParams
    case $ACTION in
        removeSecondary)
            for db in ${DATABASES//,/ };do
                II "Removing replication from secondary [$HOST_PRIMARY] for database [$db]"
                removeReplication $HOST_SECONDARY "remove-foreign-master" $db
                test "$WIPE" && removeReplication $HOST_SECONDARY "remove-foreign-replicas" $db
            done
            ;;

        removePrimary)
            #local JSON="$(httpGET \"$HOST_PRIMARY\" \"clusters/${$HOST_SECONDARY}-cluster\")"
            #local fcid=$(parseJson "id" "$JSON")
            for db in ${DATABASES//,/ };do
                II "Removing replication from primary [$HOST_PRIMARY] for database [$db]"
                removeReplication $HOST_PRIMARY "remove-foreign-replicas" $db
                test "$WIPE" && removeReplication $HOST_PRIMARY "remove-foreign-master" $db
            done
            ;;

        enableForward)
            for db in ${DATABASES//,/ };do
                dryMessage $HOST_PRIMARY $HOST_SECONDARY $db
                addReplicationOnMaster $HOST_PRIMARY $HOST_SECONDARY $CLUSTER_PRIMARY $CLUSTER_SECONDARY $db
                addReplicationOnForeign $HOST_PRIMARY $HOST_SECONDARY $CLUSTER_PRIMARY $CLUSTER_SECONDARY $db
            done
            ;;

        enableReverse)
            for db in ${DATABASES//,/ };do
                dryMessage $HOST_SECONDARY $HOST_PRIMARY $db
                addReplicationOnForeign $HOST_SECONDARY $HOST_PRIMARY $CLUSTER_PRIMARY $CLUSTER_SECONDARY $db
                addReplicationOnMaster $HOST_SECONDARY $HOST_PRIMARY $CLUSTER_PRIMARY $CLUSTER_SECONDARY $db
            done
            ;;

        waitForForestsSync)
            if "$DRY_RUN";then
                II "DRY RUN MODE: Waiting for forests for db [$db] on host [$host]."
                exit
            fi
            for db in ${DATABASES//,/ };do
                II "Waiting for forests of database [$db]"
                waitForForestsSync $HOST $db $runId &
            done
            # now wait
            keepWaiting=true
            while $keepWaiting;do
                keepWaiting=false
                for db in ${DATABASES//,/ };do
                    II "Checking forests on database [$db]"
                    if [ -f "/tmp/syncing-${db}-${runId}" ];then
                        II ".. database [$db]: sync-in-progress"
                        keepWaiting=true
                    fi
                done
                sleep 15
            done
            ;;

        *|none)
            echo "Replication: No action selected. Must be one of [--remove-[master|replica], --enable-[forward|reverse]]"
            ;;
    esac
}

showParams() {
    echo "ACTION:         $ACTION"
    echo "HOST_PRIMARY:   $HOST_PRIMARY"
    echo "HOST_SECONDARY: $HOST_SECONDARY"
    echo "DATABASES:      $DATABASES"
    echo "USER:           $USER"
    #exit
}

# The main worker functions
{
    waitForForestsSync() {
        local host=$1
        local db=$2
        local runId=$3
        local lock="/tmp/syncing-${db}-${runId}"
        touch $lock
        local forests=$(getForests $host $db)
        echo "$forests"
        local stillOpen=true
        while $stillOpen;do
            stillOpen=false
            for f in ${forests//,/ };do
                II "Checking if forest [$f] is ready..."
                local JSON=$(httpGET $host "forests/${f}/properties?format=json")
                local avail=$(parseJson availability "$JSON")
                if [ "$avail" != "online" ];then
                    II ".. Still waiting on forest [$f]."
                    stillOpen=true
                else
                    II ".. Forest [$f] is online and ready."
                fi
            done
            sleep 10
        done
        II "Forests for database [$db] are ready!"
        rm $lock
    }
    removeReplication() {
        local host=$1
        local mode=$2
        local db=$3
        if "$DRY_RUN";then
            II "DRY RUN MODE: Remove replica for db [$db] on host [$host] in mode [$mode]."
            exit
        fi
        local replicaPayload=
        if [ "$mode" == "remove-foreign-replicas" ];then
            replicaPayload=", \"foreign-database-name\": [ \"${db}\" ]"
        fi
        local payload="{
            \"operation\": \"${mode}\"
            $replicaPayload
        }"
        local responseCode=$(httpPOST "$host" databases/${db} "$payload")
        if [[ "$responseCode" == "200" ]];then
            II "Replication removed from [$host] for database [$db]"
        else
            echo "Script failed to remove replication! Response [$responseCode]"
        fi
    }

    addReplicationOnMaster() {
        II "Adding replication on local"
        # steps to add it on the master side
        local master=$1
        local replica=$2
        local cluster=$3
        local foreignCluster=$4
        local db=$5
        local payload="{
            \"operation\": \"add-foreign-replicas\",
            \"foreign-replica\": [{
                \"foreign-cluster-name\": \"${foreignCluster}\",
                \"foreign-database-name\": \"${db}\",
                \"connect-forests-by-name\": true,
                \"lag-limit\": 15,
                \"enabled\": true,
                \"queue-size\":10
            }]
        }"
        local responseCode=$(httpPOST "$master" databases/${db} "$payload")
        if [[ "$responseCode" == "200" ]]; then
            echo "=================== ADDED REPLICATION ON MASTER =============================="
        else
            echo "Could not add replication on master [$master] for database [$db]"
        fi
    }

    addReplicationOnForeign() {
        II "Adding replication on foreign"
        local master=$1
        local replica=$2
        local cluster=$3
        local foreignCluster=$4
        local db=$5
        local payload="{
            \"operation\": \"set-foreign-master\",
            \"foreign-master\": {
                \"foreign-cluster-name\": \"${cluster}\",
                \"foreign-database-name\": \"${db}\",
                \"connect-forests-by-name\": true
            }
        }"
        local responseCode=$(httpPOST "$replica" databases/${db} "$payload")
        if [[ "$responseCode" == "200" ]]; then
            echo "=================== ATTACHED REPLICATION ON FOREIGN =============================="
        else
            echo "ERROR: Could not add replication on master [$replica] for database [$db]"
            echo "       Status code [$responseCode]"
        fi
    }

    dryMessage() {
        local h1=$1
        local h2=$2
        local db=$3
        if "$DRY_RUN";then
            II "DRY RUN MODE: Replicating from Primary [$h1] to Secondary [$h2] for database [$db]"
            exit
        fi
    }
}

# helper functions
{
    processArgs() {
        ACTION=none
        WIPE=false
        # made it hardcode because it was picking the host from ~/.bashrc [localhost]
        HOST_PRIMARY=$HOST
        HOST_SECONDARY=$HOST_SECONDARY
        USER=$USER_ARCH
        PASS=$PASS_ARCH
        while [ "$#" -ne "0" ];do
            case $1 in
                # ACTIONS
                --remove)
                    shift
                    case $1 in
                        primary) ACTION="removePrimary" ;;
                        secondary) ACTION="removeSecondary" ;;
                        *)
                            echo "Unknown option for --remove switch [$1]. Must be primary or secondary"
                            exit 1
                            ;;
                    esac
                    shift
                    ;;
                --enable-forward) shift; ACTION="enableForward" ;;
                --enable-reverse) shift; ACTION="enableReverse" ;;
                --username) shift; USER=$1;shift ;;
                --password) shift; PASS=$1;shift ;;
                --wait-for-forests) shift; ACTION="waitForForestsSync" ;;
                # OPTIONS
                --primary-host) shift;HOST_PRIMARY=$1;shift ;;
                --secondary-host) shift;HOST_SECONDARY=$1;shift ;;
                --primary-cluster) shift;CLUSTER_PRIMARY=$1;shift ;;
                --secondary-cluster) shift;CLUSTER_SECONDARY=$1;shift ;;
                --host) shift;HOST=$1;shift ;;
                --wipe) shift;true=true ;;
                --dry-run) shift;DRY_RUN=$1;shift ;;
                --databases) shift; DATABASES=$1;shift ;;
                --help) shift;usage;exit ;;
                *) echo "Unknown "; shift ;;
            esac
        done

        if [ -z "$ACTION" ];then
            echo "No action defined. Provide --remove --enable"
            usage
            exit 1
        fi
        if [ -z "$DATABASES" ];then
            echo "No database provided. use --databases <DATABASES>"
            usage
            exit 1
        fi
        if [ -z "$USER" ];then
            echo "No username provided. use --username <username>"
            usage
            exit 1
        fi
        if [ -z "$PASS" ];then
            echo "No password provided. use --password <password>"
            usage
            exit 1
        fi
    }
}

DRY_RUN=false
main $@

#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/util.sh"
#

set -e

usage() {
    echo "
ML_DBA / cluster / replication

USAGE: ./$0 <ACTION> [OPTIONS]

  ACTIONS:
      --remove            Removes replication on ...
          primary           primary cluster
          secondary         secondary cluster

      --enable-forward    Enables replication from primary to secondary
      --enable-reverse    Enables replication from secondary to primary

  OPTIONS (optional: defaults taken from environment variables):
      --database            Database to act on.
      --username            Username if no \$ML_ADMIN variable is defined. Assumed same for both clusters.
        --username-local    Username for local cluster. Overrides --username for local cluster.
        --username-foreign  Username for foreign cluster. Overrides --username for foreign cluster.

      --password            Password if no \$ML_PASSWORD variable is defined. Assumed same for both clusters.
        --password-local    Password for local cluster. Overrides --password for local cluster.
        --password-foreign  Password for foreign cluster. Overrides --password for foreign cluster.

      --primary-host        Provide hostname for primary cluster.
      --secondary-host      Provide hostname for secondary cluster.

      --help                Show this help message.
      "
  #
  # Don't advertise this feature until tested with certs
  #
  # --wait-for-sync       Wait for forests to sync before returning. This is the safest
  #                         and most reliable way to ensure that replication is ready.
  #                         This, along with other options should be scripted in a
  #                         deployment script.
}

main() {
    local runId=$(date +%s)
    mandatoryEnv \
        "ML_LOCAL_PROTOCOL" "ML_FOREIGN_PROTOCOL" \
        "ML_LOCAL_ADMIN" "ML_LOCAL_PASSWORD" "ML_LOCAL_HOST" \
        "ML_FOREIGN_ADMIN" "ML_FOREIGN_PASSWORD" "ML_FOREIGN_HOST"
    processArgs $@

    # showParams
    case $ACTION in

        # primary and local are interchangeable but we are moving to local/foreign
        removePrimary|removeLocal)
            II "Removing replication from primary [$ML_LOCAL_HOST] for database [$ML_DATABASE]"
            removeReplication \
                $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL \
                "remove-foreign-replicas" $ML_DATABASE \
                $ML_LOCAL_ADMIN "$ML_LOCAL_PASSWORD" \
                $ML_LOCAL_CERT_PATH "$ML_LOCAL_CERT_PASSWORD"

            if "$WIPE";then 
                removeReplication \
                    $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL \
                    "remove-foreign-master" $ML_DATABASE \
                    $ML_LOCAL_ADMIN "$ML_LOCAL_PASSWORD" \
                    $ML_LOCAL_CERT_PATH "$ML_LOCAL_CERT_PASSWORD"
            fi
            ;;

        removeSecondary|removeForeign)
            II "Removing replication from secondary [$ML_LOCAL_HOST] for database [$ML_DATABASE]"
            removeReplication \
                $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL \
                "remove-foreign-master" $ML_DATABASE \
                $ML_FOREIGN_ADMIN "$ML_FOREIGN_PASSWORD" \
                $ML_FOREIGN_CERT_PATH "$ML_FOREIGN_CERT_PASSWORD"

            if "$WIPE";then
                removeReplication \
                    $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL \
                    "remove-foreign-replicas" $ML_DATABASE \
                    $ML_FOREIGN_ADMIN "$ML_FOREIGN_PASSWORD" \
                    $ML_FOREIGN_CERT_PATH "$ML_FOREIGN_CERT_PASSWORD"
            fi
            ;;

        # forward is always direction from local to foreign
        enableForward)
            dryMessage $ML_LOCAL_HOST $ML_FOREIGN_HOST $ML_DATABASE

            LL $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL \
                $ML_LOCAL_CLUSTER_NAME $ML_FOREIGN_CLUSTER_NAME \
                $ML_DATABASE \
                $ML_LOCAL_ADMIN "$ML_LOCAL_PASSWORD" \
                "CERTS ..." \
                $ML_LOCAL_CERT_PATH "$ML_LOCAL_CERT_PASSWORD"

            addReplicationOnMaster \
                $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL \
                $ML_LOCAL_CLUSTER_NAME $ML_FOREIGN_CLUSTER_NAME \
                $ML_DATABASE \
                $ML_LOCAL_ADMIN "$ML_LOCAL_PASSWORD" \
                $ML_LOCAL_CERT_PATH "$ML_LOCAL_CERT_PASSWORD"

            addReplicationOnForeign \
                $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL \
                $ML_LOCAL_CLUSTER_NAME $ML_FOREIGN_CLUSTER_NAME \
                $ML_DATABASE \
                $ML_FOREIGN_ADMIN "$ML_FOREIGN_PASSWORD" \
                $ML_FOREIGN_CERT_PATH "$ML_FOREIGN_CERT_PASSWORD"
            ;;

        # reverse is always direction from foreign to local
        enableReverse)
            dryMessage $ML_FOREIGN_HOST $ML_LOCAL_HOST $ML_DATABASE
            addReplicationOnForeign \
                $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL \
                $ML_LOCAL_CLUSTER_NAME $ML_FOREIGN_CLUSTER_NAME \
                $ML_DATABASE \
                $ML_FOREIGN_ADMIN "$ML_FOREIGN_PASSWORD" \
                $ML_FOREIGN_CERT_PATH "$ML_FOREIGN_CERT_PASSWORD"

            addReplicationOnMaster \
                $ML_FOREIGN_HOST $ML_FOREIGN_PROTOCOL $ML_LOCAL_HOST $ML_LOCAL_PROTOCOL \
                $ML_LOCAL_CLUSTER_NAME $ML_FOREIGN_CLUSTER_NAME \
                $ML_DATABASE \
                $ML_LOCAL_ADMIN "$ML_LOCAL_PASSWORD" \
                $ML_FOREIGN_CERT_PATH "$ML_FOREIGN_CERT_PASSWORD"
            ;;

        # It can be dangerous to enable replication withoutforests being in sync.
        # This is a helper function to wait until all forests are in sync.
        waitForForestsSync)
            if "$DRY_RUN";then
                II "DRY RUN MODE: Waiting for forests for db [$ML_DATABASE] on host [$host]."
                exit
            fi
            
            II "Waiting for forests of database [$ML_DATABASE]"
            waitForForestsSync $HOST $ML_DATABASE $runId &
            
            # now wait
            keepWaiting=true
            while $keepWaiting;do
                keepWaiting=false
                II "Checking forests on database [$ML_DATABASE]"
                if [ -f "/tmp/syncing-${ML_DATABASE}-${runId}" ];then
                    II ".. database [$ML_DATABASE]: sync-in-progress"
                    keepWaiting=true
                fi
                sleep 15
            done
            ;;

        *|none)
            echo "Replication: No action selected. Must be one of [--remove-[master|replica], --enable-[forward|reverse]]"
            ;;
    esac
}

showParams() {
    echo "ACTION:          $ACTION"
    echo "ML_LOCAL_HOST:   $ML_LOCAL_HOST"
    echo "ML_FOREIGN_HOST: $ML_FOREIGN_HOST"
    echo "DATABASE:        $ML_DATABASE"
    echo "USER LOCAL:      $ML_LOCAL_ADMIN"
    echo "USER FOREIGN:    $ML_FOREIGN_ADMIN"
    echo "FOREIGN CERT:    $ML_FOREIGN_CERT_PATH"
    echo "LOCAL CERT:      $ML_LOCAL_CERT_PATH"
    echo "WIPE:            $WIPE"
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
        ## Assign positional parameters
        local host=$1
        local protocol=$2
        local mode=$3
        local db=$4
        local user=$5
        local pass=$6
        local certPath=$7
        local certPass=$8

        II "Removing replication from [$host] for database [$db]"
        ##
        ## Execute the command
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
        local responseCode=$(httpPOST \
             "$host" "$protocol" \
            databases/${db} "$payload" \
            "$user" "$pass" "$certPath" "$certPass" \
        )
        if [[ "$responseCode" == "200" ]];then
            II "Replication removed from [$host] for database [$db]"
        else
            echo "Script failed to remove replication! Response [$responseCode]"
        fi
    }

    addReplicationOnMaster() {
        ## Assign positional parameters
        local master=$1
        local masterProtocol=$2
        local replica=$3
        local replicaProtocol=$4
        local cluster=$5
        local foreignCluster=$6
        local db=$7
        local user=$8
        local pass=$9
        local certPath=${10}
        local certPass=${11}
        ##
        II "Adding replication on local"
        # steps to add it on the master side
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
        local responseCode=$(httpPOST \
            "$master" "$masterProtocol" \
            databases/${db} "$payload" \
            "$user" "$pass" "$certPath" "$certPass" \
        )
        if [[ "$responseCode" == "200" ]]; then
            echo "=================== ADDED REPLICATION ON MASTER =============================="
        else
            echo "Could not add replication on master [$master] for database [$db]"
            echo $responseCode
            exit 1
        fi
    }

    addReplicationOnForeign() {
        # Assign positional parameters
        local master=$1
        local masterProtocol=$2
        local replica=$3
        local replicaProtocol=$4
        local cluster=$5
        local foreignCluster=$6
        local db=$7
        local user=$8
        local pass=$9
        local certPath=${10}
        local certPass=${11}
        ##
        II "Adding replication on foreign"
        # steps to add it on the replica side
        local payload="{
            \"operation\": \"set-foreign-master\",
            \"foreign-master\": {
                \"foreign-cluster-name\": \"${cluster}\",
                \"foreign-database-name\": \"${db}\",
                \"connect-forests-by-name\": true
            }
        }"
        local responseCode=$(httpPOST \
            "$replica" "$replicaProtocol" \
            databases/${db} "$payload" \
            "$user" "$pass" "$certPath" "$certPass" \
        )
        if [[ "$responseCode" == "200" ]]; then
            echo "=================== ATTACHED REPLICATION ON FOREIGN =============================="
        else
            echo "ERROR: Could not add replication on master [$replica] for database [$db]"
            echo "       Status code [$responseCode]"
            exit 1
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
        ML_LOCAL_HOST=$HOST
        ML_FOREIGN_HOST=$ML_FOREIGN_HOST
        while [ "$#" -ne "0" ];do
            case $1 in
                # ACTIONS
                --remove)
                    shift
                    case $1 in
                        primary|local) ACTION="removePrimary" ;;
                        secondary|foreign) ACTION="removeSecondary" ;;
                        *)
                            echo "Unknown option for '--remove' switch [$1]."
                            echo "Must be one of: (primary, local, secondary, foreign)"
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
                --primary-host) shift;ML_LOCAL_HOST=$1;shift ;;
                --secondary-host) shift;ML_FOREIGN_HOST=$1;shift ;;
                --primary-cluster) shift;ML_LOCAL_CLUSTER_NAME=$1;shift ;;
                --secondary-cluster) shift;ML_FOREIGN_CLUSTER_NAME=$1;shift ;;
                --host) shift;HOST=$1;shift ;;
                --wipe) shift;WIPE=true ;;
                --dry-run) shift;DRY_RUN=$1;shift ;;
                --database) shift; ML_DATABASE=$1;shift ;;
                --help) shift;usage;exit ;;
                *) echo "Unknown switch [$1]"; shift ;;
            esac
        done

        if [ -z "$ACTION" ];then
            echo "No action defined. Provide --remove --enable"
            usage
            exit 1
        fi
        if [ -z "$ML_DATABASE" ];then
            echo "No database provided. use --databases <ML_DATABASE>"
            usage
            exit 1
        fi
        if [ -z "$ML_ADMIN" ];then
            echo "No username provided. use --username <username>"
            usage
            exit 1
        fi
    }
}

DRY_RUN=false
main $@

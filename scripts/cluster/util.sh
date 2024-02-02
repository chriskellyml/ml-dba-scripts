#!/bin/bash

ML_MANAGE_PORT=8002
ML_PROTOCOL=https

# Generic data calls
{
    getForests() {
        local host=$1
        local db=$2
        local JSON="$(httpGET $host "databases/${db}/properties?format=json")"
        local forests="$(parseJson forest "$JSON")"
        local x=${forests//u\'/}
        x=${x//\[/}
        x=${x//\]/}
        x=${x//\', /,}
        x=${x//\'/}
        echo $x
    }

    mandatoryEnv() {
        local envVar=
        for envVar in "$@"; do
            if [ -z "${!envVar}" ]; then
                echo "ERROR: Mandatory environment variable [$envVar] is not set"
                exit 1
            fi
        done
    }
}

## http help functions
{
    getCertOpts() {
        local cPath=$1
        local cPass=$2
        local certOpts=()
        if [ -n "$1" ];then
            certOpts=(--cert-type p12 --cert "$cPath:$cPass")
        fi
        echo "${certOpts[@]}"
    }

    httpGET() {
        # Assign positional parameters
        local host=$1
        local protocol=$2
        local endpoint=$3
        local user=$4
        local pass=$5
        local certOpts=$(getCertOpts $6 $7)
        ##
        local URL="${protocol}://${host}:${ML_MANAGE_PORT}/manage/v2/${endpoint}"
        # echo $URL
        #set -o xtrace
        status=$(curl \
            -s -k --digest --user "${user}:${pass}" ${certOpts[@]} \
            -X GET \
            -H "Content-Type:application/json" \
            $URL)
        #set +o xtrace
        echo "$status" 2>/dev/null
    }

    httpPOST() {
        # Assign positional parameters
        local host=$1
        local protocol=$2
        local endpoint=$3
        local payload=$4
        local user=$5
        local pass=$6
        local certOpts="$(getCertOpts $7 $8)"
        LL Endpoint $endpoint
        LL curl -s -k --digest --user "${user}:${pass}" ${certOpts[@]} -X POST --write-out 'ResponseCode: %{http_code}' -H "Content-Type:application/json" -d "$payload" "${ML_PROTOCOL}://${host}:${ML_MANAGE_PORT}/manage/v2/${endpoint}"
        status=$(curl \
            -s -k --digest --user "${user}:${pass}" ${certOpts[@]} \
            -X POST \
            --write-out 'ResponseCode: %{http_code}' \
            -H "Content-Type:application/json" \
            -d "$payload" \
            ${ML_PROTOCOL}://${host}:${ML_MANAGE_PORT}/manage/v2/${endpoint} \
        )

        # return response code
        local response=$(echo "$status" | grep "ResponseCode" | awk {'print $2'})
        if [ "$response" != "200" ]; then
            echo "ERROR: Bad response from endpoints [$endpoint]"
            echo "======"
            echo "$status"
            echo "======"
        fi
        echo "$response"
    }

    jsonPackage() {
        local f=options/$1.json
        cp $f $f.tmp
        local args=$2
        for p in ${args//,/ }; do
            local prop=$(echo $p | awk -F@ '{print $1}')
            local value=$(echo $p | awk -F@ '{print $2}')
            sed -i "s/%%$prop%%/${value//\//\\/}/g" $f.tmp
        done
        local payload="$(cat $f.tmp)"
        rm $f.tmp
        echo "$payload"
    }

    parseJson() {
        local prop=$1
        local json="$2"
        local pyString="import json,sys;obj=json.load(sys.stdin);print obj[\"$prop\"]"
        local res=$(echo "$json" | python -c "$pyString")
        echo "$res"
    }

    II() { echo "II $(date --iso-8601=seconds) $@"; }
    LL() { echo "$@" >> /tmp/ml-dba.log; }
}


init() {
   touch /tmp/ml-dba.log
   echo "---" >> /tmp/ml-dba.log 
   echo "INFO: $(date --iso-8601=seconds) Initializing ml-dba" >> /tmp/ml-dba.log 
   
}

init
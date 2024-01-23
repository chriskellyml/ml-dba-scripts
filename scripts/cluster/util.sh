#!/bin/bash

ML_MANAGE_PORT=8002
PROTOCOL=https

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
    httpGET() {
        # Assign positional parameters
        local host=$1
        local endpoint=$2

        # TODO: Add support for user/pass + cert

        ##
        local URL="$PROTOCOL://${host}:${ML_MANAGE_PORT}/manage/v2/${endpoint}"
        # echo $URL
        #set -o xtrace
        status=$(curl -s -k --digest --user "${USER}:${PASS}" -X GET \
            -H "Content-Type:application/json" \
            $URL)
        #set +o xtrace
        echo "$status" 2>/dev/null
    }

    httpPOST() {
        # Assign positional parameters
        local host=$1
        local endpoint=$2
        local payload=$3
        local user=$4
        local pass=$5
        local certPath=$6
        local certPass=$7
        ##
        # Set up cert options
        local certOpts=()
        if [ -n "$CERT_PATH" ];then
            certOpts=(--cert-type p12 --cert "$certPath:$certPass")
        fi
        #set -o xtrace
        status=$(curl -s -k --digest --user "${user}:${pass}" -X POST \
            --write-out 'ResponseCode: %{http_code}' \
            -H "Content-Type:application/json" \
            -d "$payload" \
            ${PROTOCOL}://${host}:${ML_MANAGE_PORT}/manage/v2/${endpoint})
        #set +o xtrace

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
}

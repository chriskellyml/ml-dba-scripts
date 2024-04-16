#!/bin/bash

source ./local-kub-env.sh

setupDatabase() {
  local u=$1
  local p=$2
  local protocol=$3
  local host=$4
  set -o xtrace
  curl --digest --user "$u:$p" -X POST -i \
      --data-binary @/tmp/setup-database.sjs \
      -H "Content-type: application/x-www-form-urlencoded" \
      -H "Accept: multipart/mixed; boundary=BOUNDARY" \
      "${protocol}://${host}:8000/v1/eval"
  set +o xtrace
}

setupDatabase $ML_ADMIN $ML_PASSWORD $ML_LOCAL_PROTOCOL $ML_LOCAL_HOST
setupDatabase $ML_ADMIN $ML_PASSWORD $ML_FOREIGN_PROTOCOL $ML_FOREIGN_HOST

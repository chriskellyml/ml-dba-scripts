#!/bin/bash

FORMAT=javascript

main() {
  case $1 in
    --help)
      echo "Usage: $0 <script_file>"
      ;;
    *)
      invoke "$1"
      ;;
  esac
}

invoke() {
  local fname=$1
  # if extension is xqy, FORMAT=xquery
  # if extension is sjs, FORMAT=javascript
  if [[ $fname == *xqy || $fname == *xq ]]; then
    FORMAT=xquery
  fi
  set -o xtrace
  curl --digest -sS --insecure -u "$ML_USER:$ML_PASS" -X POST \
      --data-urlencode "${FORMAT}@${fname}" \
      --data "database=lvbb-content" \
      "${ML_PROTOCOL}://${ML_HOST}:${ML_PORT}/v1/eval"
  set +o xtrace
}

main "$@"

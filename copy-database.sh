#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FROM=${FROM:?FROM is required}
TARGET=${TO:-${FROM}-clone}
LIMIT=${LIMIT:-1000000}
THREADS=${THREADS:-4}
BATCH=${BATCH:-1}
PAGELIM=${PAGELIM:-}
HOST=${HOST:-localhost}
PORT=${PORT:-8000}
USER=${USER:?USER is required}
PASS=${PASS:?PASS is required}

for value in "$LIMIT" "$THREADS" "$BATCH"; do
  if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
    printf 'LIMIT, THREADS, and BATCH must be positive integers\n' >&2
    exit 2
  fi
done

if [[ -n $PAGELIM && ! $PAGELIM =~ ^[1-9][0-9]*$ ]]; then
  printf 'PAGELIM must be a positive integer\n' >&2
  exit 2
fi

if [[ $FROM == "$TARGET" ]]; then
  printf 'FROM and TO must name different databases\n' >&2
  exit 2
fi

xquery_literal() {
  local value=${1//\'/\'\'}
  printf "'%s'" "$value"
}

eval_query() {
  local query=$1
  local database=${2:-}
  local args=(--digest --silent --show-error --fail-with-body --insecure
    --retry 10 --retry-all-errors --retry-delay 3
    --user "$USER:$PASS" --request POST
    --header 'Accept: application/json'
    --data-urlencode "xquery=$query")
  if [[ -n $database ]]; then
    args+=(--data-urlencode "database=$database")
  fi
  curl "${args[@]}" "http://$HOST:$PORT/v1/eval"
}

eval_template() {
  local template query
  template=$(<"$1")
  query=${template//@SOURCE@/$(xquery_literal "$FROM")}
  query=${query//@TARGET@/$(xquery_literal "$TARGET")}
  eval_query "$query"
}

printf 'Ensuring destination database %s exists...\n' "$TARGET"
setup_result=$(eval_template "$ROOT/src/corb/database-copy/setup/create-database.xqy")
if [[ $setup_result == *NEEDS_FORESTS* ]]; then
  printf 'Creating and attaching empty destination forests...\n'
  eval_template "$ROOT/src/corb/database-copy/setup/create-forests.xqy" >/dev/null
  eval_template "$ROOT/src/corb/database-copy/setup/attach-forests.xqy" >/dev/null
else
  printf 'Destination database already exists; using it unchanged.\n'
fi

printf 'Counting documents in %s...\n' "$FROM"
count_result=$(eval_query \
  'xquery version "1.0-ml"; xdmp:estimate(fn:doc())' "$FROM")
if [[ $count_result =~ ([0-9]+)[^0-9]*--[a-f0-9]+-+$ ]]; then
  total=${BASH_REMATCH[1]}
elif [[ $count_result =~ ([0-9]+) ]]; then
  total=${BASH_REMATCH[1]}
else
  printf 'Could not parse document count from MarkLogic response: %s\n' "$count_result" >&2
  exit 1
fi

if (( total == 0 )); then
  printf 'Source database contains no documents.\n'
  exit 0
fi

pages=$(( (total + LIMIT - 1) / LIMIT ))
if [[ -n $PAGELIM && $PAGELIM -lt $pages ]]; then
  printf 'PAGELIM=%d set; will run %d of %d page(s).\n' "$PAGELIM" "$PAGELIM" "$pages"
  pages=$PAGELIM
fi
printf 'Copying %d documents in %d page(s), up to %d documents per page.\n' \
  "$total" "$pages" "$LIMIT"

for ((page = 1; page <= pages; page++)); do
  printf 'Running CoRB page %d of %d...\n' "$page" "$pages"
  gradle --no-daemon --console=plain -p "$ROOT" corb \
    -Phost="$HOST" -Pport="$PORT" -Pusername="$USER" \
    -Psource="$FROM" -Ptarget="$TARGET" -Plimit="$LIMIT" -Ppage="$page" \
    -Pthreads="$THREADS" -Pbatch="$BATCH"
done

printf 'Database copy complete.\n'

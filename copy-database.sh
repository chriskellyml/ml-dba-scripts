#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FROM=${FROM:?FROM is required}
TARGET=${DTO:-${TO:-}}
: "${TARGET:?DTO is required}"
LIMIT=${LIMIT:-1000000}
THREADS=${THREADS:-4}
BATCH=${BATCH:-1}
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

if [[ $FROM == "$TARGET" ]]; then
  printf 'FROM and DTO must name different databases\n' >&2
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
if [[ $count_result =~ \"value\"[[:space:]]*:[[:space:]]*\"?([0-9]+) ]]; then
  total=${BASH_REMATCH[1]}
elif [[ $count_result =~ ^[[:space:]]*([0-9]+)[[:space:]]*$ ]]; then
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

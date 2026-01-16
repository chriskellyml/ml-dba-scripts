#!/bin/bash

TAIL_PID=""

# Function to clean up background processes
cleanup() {
  if [[ -n "$TAIL_PID" ]]; then
    echo "Cleaning up... Killing tail process (PID: $TAIL_PID)"
    kill -9 "$TAIL_PID" 2>/dev/null || true
    exit 0
  fi
}

# Trap script exit and interruption signals
trap cleanup EXIT INT TERM

# Default values
DEFAULT_LOG_DIR="./"
DEFAULT_PATTERN="*"
RUNNING_LOG="/tmp/running"

# Function to display help
show_help() {
  cat << EOF
Usage: ${0##*/} [OPTION]
A script to view and manage log files.

Options:
  --help                 Display this help and exit
  --sessions [PATTERN]   View logs interactively with an optional pattern
  --validation [PATTERN] Watch and filter logs based on a given pattern
  --log-dir [DIR]        Specify the log directory (default: current directory)
  --pattern [PATTERN]    Specify the base file pattern (default: *)

Examples:
  ${0##*/} --sessions
  ${0##*/} --sessions "Error"
  ${0##*/} --validation "Error"
  ${0##*/} --log-dir /path/to/logs --sessions
EOF
}

# Parse arguments
LOG_DIR="$DEFAULT_LOG_DIR"
PATTERN="$DEFAULT_PATTERN"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --log-dir)
      LOG_DIR="$2"
      shift
      ;;
    --pattern)
      PATTERN="$2"
      shift
      ;;
    --sessions|--validation)
      COMMAND="$1"
      [[ "$2" != "--"* && ! -z "$2" ]] && FILTER="$2" && shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

# Construct the full file pattern
FULL_PATTERN="${PATTERN}Log.txt"

# Check for log files in the specified directory
if [[ ! -d "$LOG_DIR" ]]; then
  echo "Log directory not found: $LOG_DIR"
  exit 1
fi

# Check if any files match the pattern in the log directory without showing extra output
if ! find "$LOG_DIR" -maxdepth 1 -type f -name "$FULL_PATTERN" >/dev/null 2>&1; then
  echo "No valid log files found in directory: $LOG_DIR"
  exit 1
fi

log_viewer() {
  cd "$LOG_DIR" || { echo "Failed to change to directory: $LOG_DIR"; exit 1; }
  clear
  echo "Running Log Viewer with pattern: $FULL_PATTERN"
  
  if [ ! -f "$(pwd)/ErrorLog.txt" ];then
    echo "No logs found in the current directory."
    exit 1
  fi

  RUNNING_LOG="${RUNNING_LOG}_${FULL_PATTERN}"
  while true; do
    >"$RUNNING_LOG"
    tail -f -q -n 0 "$(pwd)"/*$FULL_PATTERN >"$RUNNING_LOG" &
    TAIL_PID=$!
    disown $TAIL_PID
    echo "$(date) - Gathering data in [$RUNNING_LOG]. Press ENTER to view ..."
    read -r
    less -fN "$RUNNING_LOG"
    kill "$TAIL_PID" 2>/dev/null
  done
}

# Define the validation log function
validation_log() {
  echo "Filtering logs with pattern: $FILTER"
  tail -f -n 0 "$LOG_DIR"/$FULL_PATTERN | \
    awk -F"Info:" '{print $2}' | \
    grep "$FILTER" | \
    sort
}

# Execute the appropriate command
case $COMMAND in
  --sessions)
    if [[ -n "$FILTER" ]]; then
      PATTERN="$FILTER"
      FULL_PATTERN="${PATTERN}Log.txt"
    fi
    log_viewer
    ;;
  --validation)
    if [[ -z "$FILTER" ]]; then
      echo "Please provide a pattern for validation logs."
      exit 1
    fi
    validation_log
    ;;
  *)
    echo "No command provided. Use --help for usage information."
    exit 1
    ;;
esac




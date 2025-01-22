#!/bin/bash

# Default values
DEFAULT_LOG_DIR="./"
DEFAULT_PATTERN="*Log.txt"
RUNNING_LOG="/tmp/running.log"

# Function to display help
show_help() {
  cat << EOF
Usage: ${0##*/} [OPTION]
A script to view and manage log files.

Options:
  --help                 Display this help and exit
  --sessions             View logs interactively
  --validation [PATTERN] Watch and filter logs based on a given pattern
  --log-dir [DIR]        Specify the log directory (default: current directory)
  --pattern [PATTERN]    Specify the file matching pattern (default: *Log.txt)

Examples:
  ${0##*/} --sessions
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

# Check for log files in the specified directory
if [[ ! -d "$LOG_DIR" ]]; then
  echo "Log directory not found: $LOG_DIR"
  exit 1
fi

# Check if any files match the pattern in the log directory without showing extra output
if ! find "$LOG_DIR" -maxdepth 1 -type f -name "$PATTERN" >/dev/null 2>&1; then
  echo "No valid log files found in directory: $LOG_DIR"
  exit 1
fi

log_viewer() {
  clear
  echo "Running Log Viewer"
  while true; do
    >"$RUNNING_LOG"
    tail -f -q -n 0 "$LOG_DIR"/$PATTERN >"$RUNNING_LOG" &
    TAIL_PID=$!
    disown $TAIL_PID
    echo "$(date) - Gathering data. Press ENTER to view ..."
    read -r
    less -N "$RUNNING_LOG"
    kill "$TAIL_PID" 2>/dev/null
  done
}

# Define the validation log function
validation_log() {
  echo "Filtering logs with pattern: $FILTER"
  tail -f -n 0 "$LOG_DIR"/$PATTERN | \
    awk -F"Info:" '{print $2}' | \
    grep "$FILTER" | \
    sort
}

# Execute the appropriate command
case $COMMAND in
  --sessions)
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

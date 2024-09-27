#!/bin/bash

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <URL> <script_file> [--username <username>] [--password <password>]"
    exit 1
fi

URL="$1"
SCRIPT_FILE="$2"

shift 2

USERNAME=""
PASSWORD=""

# Process optional arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        *)
            # Unknown option
            shift
            ;;
    esac
done

# If username is empty, prompt for it
if [ -z "$USERNAME" ]; then
    read -p "Enter username: " USERNAME
fi

# If password is empty, prompt for it (mask input)
if [ -z "$PASSWORD" ]; then
    read -s -p "Enter password: " PASSWORD
    echo
fi

# Determine the format based on file extension
EXT="${SCRIPT_FILE##*.}"

if [[ "$EXT" == "js" || "$EXT" == "sjs" ]]; then
    FORMAT="javascript"
elif [[ "$EXT" == "xq" || "$EXT" == "xqy" ]]; then
    FORMAT="xquery"
else
    echo "Unsupported script file extension: $EXT"
    exit 1
fi

# Verify the script file exists
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "Script file not found: $SCRIPT_FILE"
    exit 1
fi

# Make the curl call directly, outputting any response or errors
curl --digest -sS --insecure -u "$USERNAME:$PASSWORD" -X POST \
    --data-urlencode "${FORMAT}@${SCRIPT_FILE}" \
    "${URL}/v1/eval"

# Exit with the exit code of the curl command
exit $?



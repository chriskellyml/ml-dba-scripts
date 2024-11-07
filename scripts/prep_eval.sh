#!/bin/bash

# Default values
database="Documents"
modules=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --xqy) input_file="$2"; shift ;;
    --database) database="$2"; shift ;;
    --modules) modules="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Check if input file is provided
if [ -z "$input_file" ]; then
  echo "Usage: bash prep.sh --xqy foo.xqy [--database database_name] [--modules module_name]"
  exit 1
fi

# Extract the filename and contents
filename=$(basename "$input_file" .xqy)
output_file="_${filename}.xqy"

# Read the contents of the input file
contents=$(<"$input_file")

# Create the output XQuery file with contents, database, and modules embedded in the template
cat << EOF > "$output_file"
xquery version "1.0-ml";

xdmp:eval(<root><![CDATA[
$contents
]]></root>//text(), (), <options xmlns="xdmp:eval">
  <database>{xdmp:database("$database")}</database>
  <modules>{xdmp:database("$modules")}</modules>
</options>)
EOF

echo "Created $output_file with embedded contents from $input_file, database set to $database, and modules set to $modules"

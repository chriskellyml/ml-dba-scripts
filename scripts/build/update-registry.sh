#!/bin/bash

# scan the contents of the qconsole folder and generate a "mon-ami" compatible registry file
# To do this, we install the mon-ami npm module and use the `mon-ami scan` command
# - npm install -D @ml-mon-ami
clear
line=$(cat .git/config | grep -A 1 "origin")
proto=$(echo "$line" | grep url| awk -F"http" '{print $2}')
echo "proto1: $proto"
if [[ $proto = s* ]]; then
  proto="https"
else
  proto="http"
fi

rest=$(echo "$line" | grep url | awk -F"@github.com" '{print $2}')
rest=${rest%.git}
url="https://raw.githubusercontent.com${rest}/main"
scan \
  --folder ./qconsole/ \
  --name mldb \
  --repository "$url" \
  --outfile "registry.json"

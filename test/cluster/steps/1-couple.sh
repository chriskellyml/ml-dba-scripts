#!/bin.bash
# Run from top-level directory
if [ ! -d .git ]; then
    echo "Please run this script from the top-level directory of the project"
    exit 1
fi

source test/cluster/local-docker-env.sh
bash scripts/cluster/couple.sh --run 

#!/bin/bash

chmod +x evaler.sh

echo 'fn:sum((1, 41))' > /tmp/test.xq
cat /tmp/test.xq
./evaler.sh "http://localhost:8000" /tmp/test.xq --username admin --password admin

echo 'Math.max(1, 42)' > /tmp/test.js
cat /tmp/test.js
./evaler.sh "http://localhost:8000" /tmp/test.js --username admin --password admin

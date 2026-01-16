#!/bin/bash
#
cd /tmp
source ./local-kub-env.sh

mkdir -p testdocs
# create a number of test docs to be distributed
for i in {1..100}; do
  echo "<contents>This is test doc $i</contents>" > /tmp/testdocs/doc-$i.xml
done

# using MarkLogic v1/documents endpoint push the documents to the primary node
for i in {1..100}; do
  curl -s -X PUT -d @/tmp/testdocs/doc-$i.xml \
    -H "Content-type: application/xml" \
    -u ${ML_ADMIN}:${ML_PASSWORD} --digest \
    "${ML_LOCAL_PROTOCOL}://${ML_LOCAL_HOST}:8000/v1/documents?database=${ML_DATABASE}&uri=/testdocs/doc-$i.xml"
done

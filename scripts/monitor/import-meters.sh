#!/bin/bash

metersDb="meters"

mlcp.sh import \
  -host localhost \
  -port 8005 \
  -username admin \
  -password admin \
  -mode local \
  -input_file_path ./Meters \
  -database $metersDb
  -input_compressed true \
  -output_collections meters 

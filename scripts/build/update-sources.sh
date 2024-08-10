#!/bin/bash

function cpIfExists() {
  if [ -f "$1" ];then
    cp $1 $2
  fi 
}

cpIfExists ../ml-log-stream/src/logStreamer.js ./qconsole/ready/logStreamer.sjs
cpIfExists ../ml-log-stream/src/extract-logs.xqy ./qconsole/ready/extract-logs.xqy 

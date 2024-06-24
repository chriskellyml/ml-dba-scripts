#!/bin/bash

function cpIfExists() {
  if [ -f "$1" ];then
    cp $1 $2
  fi 
}

cpIfExists ../ml-log-stream/src/logStreamer.sjs ./qconsole/ready/logStreamer.sjs

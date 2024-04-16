# Cluster testing

This is a semi-automated test-suite for testing coupled clusters. All require
scripts are stored in the current folder (`test/cluster`) but should be
executed from the top level directory.

If you have specific needs, modify the docker-compose file and scripts as
required.

## Pre-requisites

Make sure other docker images are not running or occupying the same ports as
defined in the docker-compose.yml file.

A local marklogic docker image named marklogicdb/marklogic-db should exist in
your docker library. Otherwise, modify the docker-compose.yml file.

You should add the hostnames for the cluster nodes to your local hosts file. i.e.

    127.0.0.1   docker.cluster1-node1.internal
    127.0.0.1   docker.cluster2-node1.internal

## Instructions

### Set up the local primary and secondary clusters

    bash test/cluster/steps/0-setup.sh

If the hosts file has been udpated, you can check this is working by visiting
`http://docker.cluster2-node1.internal:8000` in your browser which is the same as `localhost:8100`

### Couple the clusters using the scripts

Check clusters are not coupled here: 

    bash test/cluster/steps/1-couple.sh --run

Verify coupling using same link:





# Cluster testing

This is a semi-automated test-suite for testing coupled clusters. All require
scripts are stored in the current folder (`test/cluster`) but should be
executed from the top level directory.

If you have specific needs, modify the docker-compose file and scripts as
required.

## Pre-requisites

This test depends on the marklogic-kubernetes helm chart. Instructions for
setup and Pre-requisites for kubernetes are described there.

    https://github.com/marklogic/marklogic-kubernetes/blob/master/docs/Local_Development_Tutorial.md

## Instructions

### Optional teardown

If uncertain, please remove the existing pods first. You can check the presense
of pods with the name `marklogic-local-dev-env-*` with the command:

    kubectl get pods --all-namespaces

Remove using the following command which could take up to minute.

    bash test/cluster/teardown.sh

### Set up the local primary and secondary clusters

    bash test/cluster/setup.sh

To log into either admin inteface in the browser use:

    chart=primary
    kubectl --namespace marklogic-${chart} port-forward marklogic-local-dev-env-0 8000 8001 8002 7997

### Test steps

Log into primary cluster node1 as follows:

    kubectl exec --namespace marklogic-primary -it marklogic-local-dev-env-0 -- /bin/bash

Change to the /tmp directory and execute each of the steps in order,
inspecting the status of the primary and secondary cluster at each
stage in between through ports 8000-8002. e.g.

    cd /tmp
	# Check that clusters are not coupled
	bash 1-couple.sh
	# check if clusters are coupled but testdb is not created
	bash 2-create-database.sh
	# Check that test db is created but replication is not setup
	# etc. etc.





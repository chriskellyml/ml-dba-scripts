# Some marklogic docker examples:

Some simple docker images to base new project on. copy to root folder and add
scripts as needed.

## Simple image

To run, execute:

    cd simple
    docker-compose -f simple-docker.yaml up --build

## Cluster 3-node

    cd simple
    docker-compose -f marklogic-cluster-3-node.yaml up --build

## Custom image

Modify the marklogic Dockerfile to suit your needs. Create folder. Modify start
up directories. Install additional tools as per you r needs.

    cd custom-image
    bash docker.sh


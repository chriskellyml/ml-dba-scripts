#!/bin/bash
#
set -e

main() {
  init
  startMinikube
  installHelmChart
  
  cd test/cluster 
}

installHelmChart() {
  echo "ADDING HELM REPO..."
  helm repo add marklogic https://marklogic.github.io/marklogic-kubernetes/
  # ensure the values-primary.yaml file exists and then run helm
  if [ ! -f values-primary.yaml ]; then
    echo "values-primary.yaml file not found"
    exit 1
  fi
  helm install marklogic-local-dev-env \
    marklogic/marklogic --version=1.0.0-ea1 --values values-primary.yaml

  # wait until the pod is in a running state
}

startMinikube() {
  # Check we are at the top level directory
  # That the directory with .git and a test folder
  if [ ! -d .git ] || [ ! -d test ]; then
    echo "Please run this script from the top-level directory of the project"
    exit 1
  fi
  
  # start minikube if it's not running
  if ! minikube status > /dev/null 2>&1
  then
    echo "STARTING MINIKUBE..."
    minikube start
  else
    echo "MINIKUBE IS ALREADY RUNNING"
  fi

  # verify minikube is running
  if ! minikube status > /dev/null 2>&1
  then
    echo "MINIKUBE FAILED TO START"
    exit 1
  fi
}

init() {
  # Check that minikube is available
  if ! command -v minikube &> /dev/null
  then
      echo "minikube could not be found"
      exit
  fi
  # Check that kubectl is available
  if ! command -v kubectl &> /dev/null
  then
      echo "kubectl could not be found"
      exit
  fi
  # Check that helm is available
  if ! command -v helm &> /dev/null
  then
      echo "helm could not be found"
      exit
  fi
  # Check that docker is available
  if ! command -v docker &> /dev/null
  then
      echo "docker could not be found"
      exit
  fi
}

main "$@"

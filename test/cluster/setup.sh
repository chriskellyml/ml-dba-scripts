#!/bin/bash
set -e

main() {
  init
  startMinikube
  installHelmCharts
  prepPod
}

prepPod() {
  echo "PREPPING POD..."
  copyFile() {
    kubectl cp --namespace marklogic-primary $1 marklogic-local-dev-env-0:$2
  }
  copyFile scripts/cluster/couple.sh /tmp/couple.sh
  copyFile scripts/cluster/replication.sh /tmp/replication.sh
  copyFile scripts/cluster/util.sh /tmp/util.sh
  # Add test data
  copyFile test/cluster/setup-database.sjs /tmp/setup-database.sjs
  copyFile test/cluster/local-docker-env.sh /tmp/local-docker-env.sh
  # loop over each document in teh test/cluster/steps folder
  cd test/cluster/steps
  for f in $(ls); do
    copyFile $f /tmp/${f}
  done
}
installHelmCharts() {
  echo "ADDING HELM REPO..."
  helm repo add marklogic https://marklogic.github.io/marklogic-kubernetes/
  #
  # ensure the values-primary.yaml file exists and then run helm
  installNextChart() {
    local chart=$1
    local valuesFile=test/cluster/values-${chart}.yaml
    # create namespace marklogic-${chart} if it doesn't exist
    echo "CHECKING NAMESPACES ..."
    kubectl get namespace marklogic-${chart} || kubectl create namespace marklogic-${chart}
    if [ ! -f $valuesFile ]; then
      echo "$valuesFile file not found"
      exit 1
    fi
    echo "INSTALLING CHART [$chart]..."
    helm upgrade --install marklogic-local-dev-env marklogic/marklogic \
      --version=1.0.0-ea1 \
      --values $valuesFile \
      --namespace marklogic-${chart}
    # wait until the pod is in a running state
    echo "WAITING FOR POD TO BE READY..."
    kubectl wait --for=condition=ready pod \
      -l app.kubernetes.io/instance=marklogic-local-dev-env \
      -n marklogic-${chart} \
      --timeout=300s
    echo "CHART [$chart] INSTALLED SUCCESSFULLY!"
  }
  installNextChart "primary"
  installNextChart "secondary" 
}

startMinikube() {
  # Check we are at the top level directory
  # That the directory with .git and a test folder
  if [ ! -d .git ] || [ ! -d test ]; then
    echo "Please run this script from the top-level directory of the project"
    exit 1
  fi
  
  # start minikube if its not running
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

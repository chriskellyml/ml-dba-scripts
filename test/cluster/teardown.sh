#!/bin/bash
#

main() {
  deletePod primary
  deletePod secondary
  deletePvs primary
  deletePvs secondary
}

deletePod() {
  local chart=$1
  echo "DELETING PODS FOR CHART [$chart]..."
  helm delete marklogic-local-dev-env -n marklogic-${chart}
}
deletePvs() {
  local chart=$1

  for pvc in $(kubectl get pvc -n marklogic-${chart}|awk '{print $1}'|tail -n+2);do
    echo "DELETING PVC $pvc..."
    kubectl delete pvc $pvc --namespace marklogic-${chart}
  done

  for pv in $(kubectl get pvc -n marklogic-${chart}|awk '{print $3}'|tail -n+2);do
    echo "DELETING PV $pv..."
    kubectl delete pv $pv --namespace marklogic-${chart}
  done
}

main

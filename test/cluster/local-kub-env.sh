#!/bin/bash
# 

# COMMON SETTINGS
export ML_ADMIN=admin
export ML_PASSWORD=admin
export ML_PROTOCOL=http
export ML_DATABASE=testdb

# LOCAL SETTINGS
export ML_LOCAL_ADMIN=admin
export ML_LOCAL_PASSWORD=admin
export ML_LOCAL_PROTOCOL=http
export ML_LOCAL_HOST=marklogic-local-dev-env.marklogic-primary.svc.cluster.local
export ML_LOCAL_CLUSTER_NAME=marklogic-local-dev-env-0.marklogic-local-dev-env-headless.marklogic-primary.svc.cluster.local-cluster
export ML_LOCAL_CERT_PATH=
export ML_LOCAL_CERT_PASSWORD=

# FOREIGN SETTINGS
export ML_FOREIGN_ADMIN=admin
export ML_FOREIGN_PASSWORD=admin
export ML_FOREIGN_PROTOCOL=http
export ML_FOREIGN_HOST=marklogic-local-dev-env.marklogic-secondary.svc.cluster.local
export ML_FOREIGN_CLUSTER_NAME=marklogic-local-dev-env-0.marklogic-local-dev-env-headless.marklogic-secondary.svc.cluster.local-cluster
export ML_FOREIGN_CERT_PATH=
export ML_FOREIGN_CERT_PASSWORD=


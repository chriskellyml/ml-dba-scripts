# About

This is a collection of scripts to help with the management of a MarkLogic cluster.

## Disclaimer

The scripts herein are may be useful for managing a marklogic cluster, but are not supported by MarkLogic. We built them for our own use to save time and effort when managing our own clusters. We are sharing them in the hope that they may be useful to others, but we do not guarantee that they will work for you, or that they will not cause problems.

Above all read the script logic and *USE AT YOUR OWN RISK*.

## Set up

### Setting up certs where needed

In some environments, you will have signed certificates. To use these
with curl you can do something like this:

`openssl pkcs12 -export -out certificate.p12 -inkey privatekey.pem -in certificate.pem -certfile ca-certificates.pem`

Where public keys are stored in certificate.pem.

Later you will define the path and password for the certs in the env file defined later.

## Preparing enviromement

Copy env.sh.sample to env.my-env.sh where "my-env" is the target environment.

Change the values in the env file to suit. Then run one of the available scripts. e.g.

## Available scripts

### Coupling clusters

Clusters can be coupled, or uncoupled a follows:

#### coupling
```
# Edit env.my-env.sh with required params for "my-env"
source env.my-env.sh
bash scripts/cluster/couple.sh --run
```

#### Setting up replication

```
# Edit env.my-env.sh with required params for "my-env"
source env.my-env.sh
bash scripts/cluster/couple.sh --run
```

#### Removing replication
```
# Edit env.my-env.sh with required params for "my-env"
source env.my-env.sh
bash scripts/cluster/couple.sh --run
```

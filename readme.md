# Note

FOR TESTING PURPOSES ONLY! 

Use at your own risk. Please read the scripts do before attempting to run.

## Set up

### Setting up certs where needed

In some environments, you will have signed certificates. To use these
with curl you can do something like this:

`openssl pkcs12 -export -out certificate.p12 -inkey privatekey.pem -in certificate.pem -certfile ca-certificates.pem`

Where public keys are stored in certificate.pem.

Later you will define the path and password for the certs in the env file defined later.

## Usage

Copy env.sh.sample to env.my-env.sh where "my-env" is the target environment.

Change the values in the env file to suit. Then run one of the available scripts. e.g.

## Available scripts

### Coupling clusters

```
# Edit env.my-env.sh with required params for "my-env"
source env.my-env.sh
bash scripts/cluster/couple.sh
```

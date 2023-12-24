# Note

For testing only. Use at your own risk. Read what the scripts do before attempting to run.

# Usage

Copy env.sh.sample to env.my-env.sh where "my-env" is the target environment.

Change the values in the env file to suit. Then run one of the available scripts. e.g.

## Coupling clusters

```
# Edit env.my-env.sh with required params for "my-env"
source env.my-env.sh
bash scripts/cluster/couple.sh
```

#/bin/bash
# Example assumes at least 6 cores available

ML_PID=$(pgrep -f MarkLogic|head -1)
if [ -z "$ML_PID" ]; then
    echo "MarkLogic is not running"
    exit 1
fi

echo ""
echo "Current CPU affinity:"
echo "- MarkLogic: $(taskset -pc $ML_PID)"

# Let's run MarkLogic on vCPUs 0-4
sudo taskset -cp 0-4 $ML_PID > /dev/null 2>&1

check_stress_is_installed() {
    # Install stress if not already installed
    if ! rpm -q stress; then
        sudo yum install epel-release
        sudo yum update -y
        sudo yum install -y
    fi
}
check_stress_is_installed > /dev/null 2>&1

# Lets run stress on vCPUs 5-6

sudo taskset -c 5,6 stress --cpu 2 > /dev/null 2>&1 &
STRESS_PID=$(pgrep -f stress|head -1)

echo ""
echo "Updated CPU affinity:"
echo "- MarkLogic: $(taskset -pc $ML_PID)"
echo "- stress: $(taskset -pc $STRESS_PID)"

# kill stress
sudo killall $STRESS_PID > /dev/null 2>&1
echo ""
#!/bin/sh
set -e
#
# Initialize the local pki
#

# Create env file from PID 1
# (as this is the old service which inherits the container environment variables)
echo "Loading environment from PID 1"
tr '\0' '\n' </proc/1/environ \
| grep -v "^\(_\|HOME\|PATH\|TERM\|HOSTNAME\|PWD\|SHLVL\)=" | tee > /etc/container.env

# Load and export env
set -a
# shellcheck disable=SC1091
. /etc/container.env
set +a

step-ca-init.sh

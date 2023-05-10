#!/bin/sh
#
# Enable services
#

set -e

# FIXME: remove this script once the initialization problem is fixed
if command -v systemctl >/dev/null 2>&1; then
    if [ -d /run/systemd/system ]; then
        echo "Workaround: restarting tedge-mapper-c8y"

        sleep 10
        sudo systemctl restart tedge-mapper-c8y
    fi
fi

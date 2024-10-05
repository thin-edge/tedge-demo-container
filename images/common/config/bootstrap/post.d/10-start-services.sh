#!/bin/sh
#
# Setup services
#

set -e

control_service() {
    name="$1"
    action="$2"
    if command -v systemctl >/dev/null 2>&1; then
        echo "Enable/$action $name"
        sudo systemctl enable "$name"

        if [ -d /run/systemd/system ]; then
            sudo systemctl "$action" "$name"
        fi
    fi
}

sleep 5

# Restart collectd as sometimes it fail with the error:
# mqtt plugin: mosquitto_connect failed: Cannot assign requested address
# Seems to be related to: https://github.com/collectd/collectd/issues/3834
control_service collectd restart

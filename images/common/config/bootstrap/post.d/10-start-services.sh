#!/bin/sh
#
# Enable services
#

set -e

start_enable_service() {
    name="$1"
    if command -v systemctl >/dev/null 2>&1; then
        echo "Enabling/starting $name"
        sudo systemctl enable "$name"

        if [ -d /run/systemd/system ]; then
            sudo systemctl start "$name"
        fi
    fi
}

sleep 5
start_enable_service "tedge-container-monitor"
start_enable_service "ssh"

#!/bin/sh
#
# Enable services
#

set -e

if command -v systemctl >/dev/null 2>&1; then
    sleep 5
    echo "Enabling/starting tedge-container-monitor"
    systemctl enable tedge-container-monitor
    systemctl start tedge-container-monitor
fi

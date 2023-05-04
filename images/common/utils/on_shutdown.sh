#!/bin/sh
set -e
tedge mqtt pub --qos 0 tedge/events/reboot_event "$(printf '{"text": "❗️❗️❗️ Warning: device is about to reboot ❗️❗️❗️", "type": "device_reboot"}')" 2>/dev/null
sleep 5

# Auto detect shutdown command
if command -v shutdown >/dev/null 2>&1; then
    sudo shutdown -r now
elif command -v openrc-shutdown >/dev/null 2>&1; then
    openrc-shutdown -r now
elif command -v systemctl >/dev/null 2>&1; then
    sudo systemctl --no-wall reboot
else
    echo "Could not find a suitable reboot command"
    exit 1
fi

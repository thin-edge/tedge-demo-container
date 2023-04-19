#!/bin/sh
set -e
tedge mqtt pub --qos 0 tedge/events/reboot_event "$(printf '{"text": "❗️❗️❗️ Warning: device is about to reboot ❗️❗️❗️", "type": "device_reboot"}')" 2>/dev/null
sleep 5
sudo shutdown -r now

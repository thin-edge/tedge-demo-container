#!/bin/sh
set -e
TOPIC_ROOT=$(tedge config get mqtt.topic_root)
TOPIC_ID=$(tedge config get mqtt.device_topic_id)
tedge mqtt pub --qos 0 "$TOPIC_ROOT/$TOPIC_ID/e/reboot_event" "$(printf '{"text": "❗️❗️❗️ Warning: device is about to reboot ❗️❗️❗️", "type": "device_reboot"}')" 2>/dev/null
sleep 5
sudo shutdown -r now

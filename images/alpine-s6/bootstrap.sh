#!/bin/sh
set -e
if [ -z "$TEDGE_MQTT_DEVICE_TOPIC_ID" ]; then
    tedge cert upload c8y
fi

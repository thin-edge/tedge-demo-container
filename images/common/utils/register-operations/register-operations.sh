#!/bin/sh
#
# Listen to command registration messages on te/
#
set -e

CONFIG_DIR="${CONFIG_DIR:-/etc/tedge}"

create_supported_operation() {
    op_name="$1"
    topic="$2"
    DEVICE_ID=$(tedge config get device.id ||:)

    topic_id=$(echo "$topic" | tr -d '[]' | cut -d/ -f2-5 | sed 's/\/*$//')
    name=$(echo "$DEVICE_ID/${topic_id}" | tr '/' ':')

    # Only add supported operations to folders which already exist (don't create any folders)
    DEVICE_DIR="$CONFIG_DIR/operations/c8y/$name"
    if [ -d "$DEVICE_DIR" ]; then
        if [ ! -f "$DEVICE_DIR/$op_name" ]; then
            echo "Creating supported operation file: $DEVICE_DIR/$op_name" >&2
            touch "$DEVICE_DIR/$op_name"
        fi
    fi
}

TOPIC_ROOT=$(tedge config get mqtt.topic_root)
echo "Listening to command registration messages: $TOPIC_ROOT/+/+/+/+/cmd/+" >&2
tedge mqtt sub "$TOPIC_ROOT/+/+/+/+/cmd/+" | \
while read -r TOPIC _PAYLOAD; do
    case "$TOPIC" in
        */firmware_update\])
            create_supported_operation "c8y_Firmware" "$TOPIC"
            ;;
    esac
done

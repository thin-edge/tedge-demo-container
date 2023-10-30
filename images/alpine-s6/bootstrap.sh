#!/bin/sh
set -e

SHOULD_PROMPT=${SHOULD_PROMPT:-1}
CAN_PROMPT=0

#
# Detect if the shell is running in interactive mode or not
if [ -t 0 ]; then
    CAN_PROMPT=1
else
    CAN_PROMPT=0
fi

prompt_value() {
    user_text="$1"
    value="$2"

    if [ "$SHOULD_PROMPT" = 1 ] && [ "$CAN_PROMPT" = 1 ]; then
        printf "\n%s (%s): " "$user_text" "${value:-not set}" >&2
        read -r user_input
        if [ -n "$user_input" ]; then
            value="$user_input"
        fi
    fi
    echo "$value"
}

if [ -z "$TEDGE_MQTT_DEVICE_TOPIC_ID" ]; then
    if [ -z "$C8Y_USER" ]; then
        C8Y_USER=$(prompt_value "Enter your Cumulocity IoT user" "$C8Y_USER")
    fi

    if [ -z "$C8Y_USER" ]; then
        echo "C8Y_USER is not set"
        exit 1
    fi

    if [ -n "$C8Y_PASSWORD" ]; then
        C8YPASS="$C8Y_PASSWORD" tedge cert upload c8y --user "$C8Y_USER"
    else
        tedge cert upload c8y --user "$C8Y_USER"
    fi
fi

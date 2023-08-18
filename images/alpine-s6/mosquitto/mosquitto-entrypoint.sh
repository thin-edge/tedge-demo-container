#!/bin/sh
set -e

TEDGE_C8Y_URL="${TEDGE_C8Y_URL:-}"
C8Y_MQTT_PORT=${C8Y_MQTT_PORT:-8883}
DEVICE_ID="${DEVICE_ID:-}"
CREATE_CERT=${CREATE_CERT:-1}

#
# Create device certificate
if [ "$CREATE_CERT" = "1" ]; then
    if command -V tedge >/dev/null 2>&1; then
        if [ -n "$DEVICE_ID" ]; then
            if [ ! -f /etc/tedge/device-certs/tedge-private-key.pem ]; then
                tedge cert create --device-id "$DEVICE_ID"
            fi
        fi
    fi
fi

#
# Upload cert if credentials are available
if [ -n "$C8Y_PASSWORD" ] && [ -n "$C8Y_USER" ]; then
    env C8YPASS="$C8Y_PASSWORD" tedge cert upload c8y --user "$C8Y_USER" ||:
fi

# Wait until the device has been registered before starting the bridge,
# otherwise the s/dat token will not receive any messages
while true; do
    echo "Registering device"

    # TODO: update to use the exit code, once ticket is resolved:
    # https://github.com/thin-edge/thin-edge.io/issues/2172
    resp=$(tedge connect c8y 2>&1 ||:)
    if echo "$resp" | grep -q "Saving configuration for requested bridge"; then
        break
    fi

    # Option 2: use mosquitto_pub
    # device_id=$(tedge config get device.id 2>/dev/null)
    # device_type=$(tedge config get device.type 2>/dev/null)
    # device_key=$(tedge config get device.key_path 2>/dev/null)
    # device_cert=$(tedge config get device.cert_path 2>/dev/null)
    # device_ca_path=$(tedge config get c8y.root_cert_path 2>/dev/null)

    # ca_options=""
    # if [ -d "$device_ca_path" ]; then
    #     ca_options="--capath $device_ca_path"
    # elif [ -f "$device_ca_path" ]; then
    #     ca_options="--cafile $device_ca_path"
    # fi

    # if mosquitto_pub \
    #     -h "$TEDGE_C8Y_URL" \
    #     -p "$C8Y_MQTT_PORT" \
    #     --key "$device_key" \
    #     --cert "$device_cert" \
    #     $ca_options \
    #     --id "$device_id" \
    #     -t "s/us" \
    #     -m "100,$device_id,$device_type"; then
    #     break
    # fi
    sleep 10
done

echo "Device has been registered successfully"

# Fix mosquitto permissions (pulled from mosquitto's own dockerfile)
user="$(id -u)"
if [ "$user" = '0' ]; then
	if [ -d "/mosquitto" ]; then
        # Use the gid and uid instead of the name
        # chown -R mosquitto:mosquitto /mosquitto || true
        chown -R "1883:1883" /mosquitto || true
    fi
	if [ -d "/etc/tedge/device-certs/" ]; then
        chown -R "1883:1883" /etc/tedge/device-certs/ || true
    fi
fi

echo "Starting mosquitto..."
exec "$@"

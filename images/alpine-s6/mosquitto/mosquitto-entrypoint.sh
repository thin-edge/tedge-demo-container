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
    sleep 10
done

echo "Device has been registered successfully"

# Fix mosquitto permissions (pulled from mosquitto's own dockerfile)
user="$(id -u)"
if [ "$user" = '0' ]; then
	if [ -d "/mosquitto" ]; then
        # Use the gid and uid instead of the name
        chown -R "1883:1883" /mosquitto || true
    fi
	if [ -d "/etc/tedge/device-certs/" ]; then
        chown -R "1883:1883" /etc/tedge/device-certs/ || true
    fi
fi

echo "Starting mosquitto..."
exec "$@"

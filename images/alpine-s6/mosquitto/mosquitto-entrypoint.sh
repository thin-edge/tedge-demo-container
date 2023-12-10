#!/bin/sh
set -e

DEVICE_ID="${DEVICE_ID:-}"

if ! command -V tedge >/dev/null 2>&1; then
    echo "missing dependency: tedge must be installed!" >&2
    exit 1
fi

#
# Create device certificate
if [ -n "$DEVICE_ID" ]; then
    PRIVATE_CERT=$(tedge config get device.key_path)
    if [ ! -f "$PRIVATE_CERT" ]; then
        tedge cert create --device-id "$DEVICE_ID"
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

    # Check if already connected
    if tedge connect c8y --test >/dev/null 2>&1 || tedge connect c8y; then
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

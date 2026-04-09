#!/bin/sh
set -e

# Fix mosquitto permissions (pulled from mosquitto's own dockerfile)
user="$(id -u)"
if [ "$user" = '0' ]; then
	if [ -d "/mosquitto" ]; then
        # Use the gid and uid instead of the name
        chown -R "1883:1883" /mosquitto || true
    fi
fi

echo "Starting mosquitto..."
exec "$@"

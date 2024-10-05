#!/bin/sh
set -e

# Enroll device with mtls
PROVISION_PASSWORD_FILE=/tmp/provisioner-password
if [ -n "$PROVISION_PASSWORD" ]; then
    printf -- '%s' "$PROVISION_PASSWORD" > "$PROVISION_PASSWORD_FILE"
    chmod 600 "$PROVISION_PASSWORD_FILE"
fi

# Note: The FEATURES variable MUST BE included in the env_keep seting of the sudoers file
(cd /tmp && sudo /usr/bin/enroll.sh --no-inherit-env --provisioner-password-file "$PROVISION_PASSWORD_FILE")
rm -f "$PROVISION_PASSWORD_FILE"

# FIXME: Remove once tedge-agent register the agent automatically
# or there is a dedicate "tedge register device" command
TOPIC_ROOT=$(tedge config get mqtt.topic_root)
TOPIC_ID=$(tedge config get mqtt.device_topic_id)
DEVICE_TYPE=$(tedge config get device.type)
while ! tedge mqtt pub --retain --qos 1 "$TOPIC_ROOT/$TOPIC_ID" "$(printf '{"@type":"child-device","type":"%s","name":"%s"}' "$DEVICE_TYPE" "$(hostname)")"; do
    sleep 5
done

# configure device scripts (run once)
if [ ! -f /etc/tedge/.configure-device-ran ]; then
    /usr/share/configure-device/runner.sh
    touch /etc/tedge/.configure-device-ran
fi

# Note: inventory scripts are run on every startup
/usr/share/tedge-inventory/runner.sh

# start agent
exec /usr/bin/tedge-agent

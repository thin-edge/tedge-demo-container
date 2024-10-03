#!/bin/sh
set -e

# Enroll device with mtls
PROVISION_PASSWORD_FILE=/tmp/provisioner-password
if [ -n "$PROVISION_PASSWORD" ]; then
    printf -- '%s' "$PROVISION_PASSWORD" > "$PROVISION_PASSWORD_FILE"
    chmod 600 "$PROVISION_PASSWORD_FILE"
fi
(cd /tmp && sudo /usr/bin/enroll.sh --no-inherit-env --provisioner-password-file "$PROVISION_PASSWORD_FILE")
rm -f "$PROVISION_PASSWORD_FILE"

# start agent
exec /usr/bin/tedge-agent

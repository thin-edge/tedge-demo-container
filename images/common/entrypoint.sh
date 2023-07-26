#!/bin/sh

set -e

CMD="$1"
shift

TEDGE_USER=${TEDGE_USER:-tedge}
TEDGE_GROUP=${TEDGE_GROUP:-tedge}

while [ $# -gt 0 ]; do
    case "$1" in
        --user)
            TEDGE_USER="$2"
            shift
            ;;
        --group)
            TEDGE_GROUP="$2"
            shift
            ;;
    esac
    shift
done

create_user_group() {
    USER="$1"
    GROUP="${2:-$USER}"
    if ! getent group "$GROUP" >/dev/null; then

        if command -v groupadd >/dev/null 2>&1; then
            groupadd --system "$GROUP"
        else
            addgroup -S "$GROUP"
        fi
    fi

    if ! getent passwd "$USER" >/dev/null; then
        if command -v groupadd >/dev/null 2>&1; then
            useradd --system --no-create-home --shell /sbin/nologin --gid "$GROUP" "$USER"
        else
            adduser -g "" -H -D "$USER" -G "$GROUP"
        fi
    fi
}

#
# Run the initializations required by each component
#

create_c8y_bridge() {
    # Create the c8y bridge configuration without relying on tedge
    BRIDGE_URL=""
    if [ -n "$C8Y_BASEURL" ]; then
        BRIDGE_URL="$C8Y_BASEURL"
    elif [ -n "$TEDGE_C8Y_URL" ]; then
        BRIDGE_URL="$TEDGE_C8Y_URL"
    fi

    cat <<EOF > /etc/tedge/mosquitto-conf/c8y-bridge.conf
### Bridge
connection edge_to_c8y
address ${BRIDGE_URL##*://}:8883
bridge_capath /etc/ssl/certs
remote_clientid ${DEVICE_ID}
local_clientid Cumulocity
bridge_certfile ${TEDGE_DEVICE_CERT_PATH:-/etc/tedge/device-certs/tedge-certificate.pem}
bridge_keyfile ${TEDGE_DEVICE_KEY_PATH:-/etc/tedge/device-certs/tedge-private-key.pem}
try_private false
start_type automatic
cleansession false
notifications true
notifications_local_only true
notification_topic tedge/health/mosquitto-c8y-bridge
bridge_attempt_unsubscribe false

### Topics
topic s/dcr in 2 c8y/ ""
topic s/ucr out 2 c8y/ ""
topic s/dt in 2 c8y/ ""
topic s/ut/# out 2 c8y/ ""
topic s/us/# out 2 c8y/ ""
topic t/us/# out 2 c8y/ ""
topic q/us/# out 2 c8y/ ""
topic c/us/# out 2 c8y/ ""
topic s/ds in 2 c8y/ ""
topic s/e in 0 c8y/ ""
topic s/uc/# out 2 c8y/ ""
topic t/uc/# out 2 c8y/ ""
topic q/uc/# out 2 c8y/ ""
topic c/uc/# out 2 c8y/ ""
topic s/dc/# in 2 c8y/ ""
topic inventory/managedObjects/update/# out 2 c8y/ ""
topic measurement/measurements/create out 2 c8y/ ""
topic event/events/create out 2 c8y/ ""
topic alarm/alarms/create out 2 c8y/ ""
topic error in 2 c8y/ ""
topic s/uat/# out 2 c8y/ ""
topic s/dat/# in 2 c8y/ ""
EOF
}

TEDGE_C8Y_URL=$( echo "$TEDGE_C8Y_URL" | sed -E "s|^https?://||" )
export TEDGE_C8Y_URL

SUDO=""

if [ "$(id -u)" = 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo -E"
elif command -v su >/dev/null 2>&1; then
    SUDO="su -c"
fi

if [ "$CMD" = "init" ]; then
    if command -v configure.sh >/dev/null 2>&1; then
        configure.sh
    fi

    if [ -n "$DEVICE_ID" ]; then
        if [ ! -f "${TEDGE_DEVICE_CERT_PATH:-/etc/tedge/device-certs/tedge-certificate.pem}" ]; then
            echo "Creating tedge certificate"
            $SUDO tedge cert create --device-id "$DEVICE_ID"

            if [ -f "/run/secrets/c8y_password.txt" ]; then
                env C8YPASS="$(cat "/run/secrets/c8y_password.txt")" tedge cert upload c8y --user "$C8Y_USER"
            fi
        fi
    fi

    # Manually create the bridge configuration
    if [ ! -f /etc/tedge/mosquitto-conf/c8y-bridge.conf ]; then
        echo "Creating bridge"
        create_c8y_bridge

        if [ ! -f /etc/tedge/mosquitto-conf/c8y-bridge.conf ]; then
            echo "Failed to create bridge"
            exit 1
        else
            echo "Created bridge"
        fi
    fi
    
    # Just exit, don't launch any other process
    exit 0
fi

# Launch binary
FULL_CMD=$(which "$CMD")

case "$FULL_CMD" in
    *mosquitto*)
        # FIXME: Why does mosquitto need to own the file?
        $SUDO chown mosquitto /etc/tedge/device-certs/tedge-private-key.pem

        while :; do
            if [ ! -f "/etc/tedge/mosquitto-conf/c8y-bridge.conf" ]; then
                printf "\nWaiting for bootstrapping. Please bootstrap using:\n\n"
                printf "\t* docker compose exec %s bootstrap.sh\n\n" "${SERVICE_NAME:-<service_name>}"
            else
                echo "tedge has been bootstrapped :)"
                break
            fi
            sleep 10
        done
        ;;
    *)
        if [ -x "$(which health_check.sh)" ]; then
            health_check.sh "mosquitto-c8y-bridge"
        fi
        ;;
esac

echo "Executing: $FULL_CMD $*"
exec "$FULL_CMD" "$@"

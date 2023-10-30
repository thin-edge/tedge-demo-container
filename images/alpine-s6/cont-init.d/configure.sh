#!/command/with-contenv sh
set -e

# TODO: thin-edge.io does not support using a given hostname instead of an ip address
EXTERNAL_ID="$(grep "$HOSTNAME" /etc/hosts | cut -f1)"
if [ -n "$EXTERNAL_ID" ]; then
    tedge config set http.bind.address "$EXTERNAL_ID"
    tedge config set c8y.proxy.bind.address "$EXTERNAL_ID"
fi

# register device
TOPIC_ROOT=$(tedge config get mqtt.topic_root)
TOPIC_ID=$(tedge config get mqtt.device_topic_id)

# FIXME: Remove once https://github.com/thin-edge/thin-edge.io/issues/2389 is resolved
# A manual registration before the service starts up seems to prevent duplicate registration messages
case "$TOPIC_ID" in
    device/main//)
        ;;
    *)
        echo "manually registering child-device" >&2
        name=$(echo "$TOPIC_ID" | cut -d/ -f2)
        body=$(printf '{"@type":"child-device","name":"%s"}' "$name")
        tedge mqtt pub -r "$TOPIC_ROOT/$TOPIC_ID" "$body"
        sleep 1
        ;;
esac

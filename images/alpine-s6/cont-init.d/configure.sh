#!/command/with-contenv sh
set -e

# FIXME: Remove when https://github.com/thin-edge/thin-edge.io/issues/2391 is resolved
# In the future the the bind and client host will be decoupled and the http.client.host will
# accept hostnames (removing the need to lookup the ip address)
if [ -n "$FIXME_TEDGE_HTTP_CLIENT_HOST" ]; then
    #
    # Configure mapper to point to correct ip address of tedge-agent http server
    #
    FIXME_TEDGE_HTTP_CLIENT_HOST_IP=$(getent hosts "$FIXME_TEDGE_HTTP_CLIENT_HOST" | cut -d' ' -f1)

    if [ -n "$FIXME_TEDGE_HTTP_CLIENT_HOST_IP" ]; then
        echo "Setting http.bind.address address to $FIXME_TEDGE_HTTP_CLIENT_HOST_IP ($FIXME_TEDGE_HTTP_CLIENT_HOST)" >&2
        tedge config set http.bind.address "$FIXME_TEDGE_HTTP_CLIENT_HOST_IP"
    fi
fi

# FIXME: Remove once https://github.com/thin-edge/thin-edge.io/issues/2389 is resolved
# A manual registration before the service starts up seems to prevent duplicate registration messages
TOPIC_ROOT=$(tedge config get mqtt.topic_root)
TOPIC_ID=$(tedge config get mqtt.device_topic_id)

if [ "$REGISTER_DEVICE" = 1 ]; then
    case "$TOPIC_ID" in
        device/main//)
            # Don't register when it is the main device
            ;;
        *)
            echo "manually registering child-device" >&2
            name=$(echo "$TOPIC_ID" | cut -d/ -f2)
            body=$(printf '{"@type":"child-device","name":"%s"}' "$name")
            tedge mqtt pub -r "$TOPIC_ROOT/$TOPIC_ID" "$body"
            sleep 1
            ;;
    esac
fi

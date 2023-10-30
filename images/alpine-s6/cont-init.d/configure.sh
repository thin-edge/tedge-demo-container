#!/command/with-contenv sh
set -e

# TODO: thin-edge.io does not support using a given hostname instead of an ip address
EXTERNAL_ID="$(grep "$HOSTNAME" /etc/hosts | cut -f1)"
if [ -n "$EXTERNAL_ID" ]; then
    tedge config set http.bind.address "$EXTERNAL_ID"
    tedge config set c8y.proxy.bind.address "$EXTERNAL_ID"
fi

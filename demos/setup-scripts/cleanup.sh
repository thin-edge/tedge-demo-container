#!/bin/bash
#
# Delete a thin-edge device and all of its dependencies
#

delete_device_and_children() {
    device="$1"
    device_id=$(c8y devices get --id "$device" --select id -o csv)

    echo "Deleting child additions"
    c8y inventory children list --id "$device_id" --childType addition --pageSize 100 | c8y inventory delete

    echo "Deleting child devices"
    c8y inventory children list --id "$device_id" --childType device --pageSize 100 | c8y inventory delete

    c8y inventory delete --id "$device_id"
}

delete_device_and_children "$1"

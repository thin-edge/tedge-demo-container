#!/bin/sh
#
# Register operations for child devices
#

usage() {
    echo "
    $0

    Register child devices and operations

    EXAMPLES
        $0 mychilddevice01
        # Register 1 child device

        $0 mychilddevice01 mychilddevice02
        # Register 2 child devices
    "
}

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --*)
            echo "Unknown flag"
            usage
            exit 1
            ;;
        *)
            mkdir -p "/etc/tedge/operations/c8y/$1"
            ;;
    esac
    shift
done

for child in /etc/tedge/operations/c8y/*/ ; do
    touch "${child}c8y_Firmware";
done

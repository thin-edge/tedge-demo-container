#!/bin/sh
set -eu

mkdir -p /run

env | while IFS='=' read -r name value; do
    # Only export variables you actually want systemd services to see.
    case "$name" in
        TEDGE_*)
            printf '%s=%s\n' "$name" "$value"
            ;;
    esac
done > /run/container-environment

# exec /sbin/init
exec /lib/systemd/systemd
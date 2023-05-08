#!/bin/sh
set -e

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

create_user_group tedge
create_user_group mosquitto

# FIXME: The directory should not have to be created by the user
LOCK_DIR="/run/lock"
mkdir -p "$LOCK_DIR"
chmod 1777 "$LOCK_DIR"

while [ $# -gt 0 ]; do
    CMD="$1"
    if command -v "$CMD" >/dev/null 2>&1; then
        "$CMD" --init
    fi
    shift
done

# Change ownership of all tedge folders
if [ -d /etc/tedge ]; then
    chown -R tedge:tedge /etc/tedge
fi

if [ -d /var/tedge ]; then
    chown -R tedge:tedge /var/tedge
fi

if [ -d /var/log/tedge ]; then
    chown -R tedge:tedge /var/log/tedge
fi

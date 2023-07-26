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

if command -v tedge >/dev/null 2>&1; then
    tedge init
fi

#!/bin/sh
set -e

if [ -z "$C8Y_USER" ]; then
    echo "C8Y_USER is not set"
    exit 1
fi

if [ -n "$C8Y_PASSWORD" ]; then
    C8YPASS="$C8Y_PASSWORD" tedge cert upload c8y --user "$C8Y_USER"
else
     tedge cert upload c8y --user "$C8Y_USER"
fi

#!/bin/sh
set -e
BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
RUN_PARTS="$BASE_DIR/scripts.d/"
NAME_FILTER="[0-9][0-9]_*"

if [ $# -gt 0 ]; then
    RUN_PARTS="$1"
fi

if [ $# -ge 2 ]; then
    NAME_FILTER="$2"
fi

_NEWLINE=$(printf '\n')
# Use -L to allow scripts to be a symlink, but this requires the results to be sorted afterwards
find -L "$RUN_PARTS" -type f -name "$NAME_FILTER" -perm 755 | sort | while IFS="$_NEWLINE" read -r file
do
    echo "Executing script: $file" >&2
    set +e
    "$file"
    SUCCESS=$?
    set -e
    echo "$OUTPUT"

    if [ "$SUCCESS" != 0 ]; then
        echo "Script failed" >&2
        continue
    fi
    echo "Script was successful" >&2
done
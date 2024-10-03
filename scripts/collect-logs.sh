#!/usr/bin/env bash
set -e

COMPOSE_FILE=${COMPOSE_FILE:-}
export COMPOSE_FILE

MAX_LINES=10000
COLLATE_LOGS=0

while [ $# -gt 0 ]; do
    case "$1" in
        --collate)
            COLLATE_LOGS=1
            ;;
        --debug)
            DEBUG=1
            ;;
    esac
    shift
done

if [ "$DEBUG" = 1 ]; then
    set -x
fi

is_systemd_container() {
    name="$1"
    docker compose exec "$name" sh -c 'command -V systemctl >/dev/null 2>&1'
}

collect_systemd_logs() {
    echo "Collecting systemd logs" >&2
    name="$1"
    docker compose exec "$name" journalctl --no-pager -n "$MAX_LINES"
}

collect_container_logs() {
    echo "Collecting container logs" >&2
    if [ $# -gt 0 ]; then
        name="$1"
        docker compose logs "$name" -n "$MAX_LINES"
    else
        docker compose logs -n "$MAX_LINES"
    fi
}

collect_logs() {
    name="$1"
    output_dir="$2"
    if is_systemd_container "$name"; then
        collect_systemd_logs "$name"
    else
        collect_container_logs "$name"
    fi
}

collect_workflow_logs() {
    name="$1"
    output_dir="$2"
    LOG_PATH=$(docker compose exec "$name" tedge config get logs.path)
    docker compose cp "$name":"$LOG_PATH/agent/" "$output_dir/" >&2 ||:
}

collect_logs_collated() {
    collect_container_logs
}

archive() {
    SRC_DIR="$1"
    OUTPUT_DIR="$2"
    TMP_FILE="$(mktemp).tar.gz"
    (cd "$SRC_DIR" && tar czvf "$TMP_FILE" .)

    rm -r "$SRC_DIR"
    mkdir -p "$OUTPUT_DIR"
    ARCHIVE_FILE="$OUTPUT_DIR/logs.tar.gz"
    echo "Creating log archive: $ARCHIVE_FILE" >&2
    mv "$TMP_FILE" "$ARCHIVE_FILE"
}

get_services() {
    docker compose ps --format "{{.Service}}" | sort
}

main() {
    OUTPUT_DIR=output/logs
    if [ "$COLLATE_LOGS" = 1 ]; then
        mkdir -p "$OUTPUT_DIR/tedge"
        collect_logs_collated "$OUTPUT_DIR" > "${name}.log"
        collect_workflow_logs tedge "$OUTPUT_DIR"
    else
        for name in $(get_services); do
            echo "Reading logs for service: $name" >&2
            mkdir -p "$OUTPUT_DIR/$name"
            collect_logs "$name" > "$OUTPUT_DIR/$name/${name}.log"
            collect_workflow_logs "$name" "$OUTPUT_DIR/$name"
        done
    fi

    archive "$OUTPUT_DIR" "$(dirname "$OUTPUT_DIR")"
}

main

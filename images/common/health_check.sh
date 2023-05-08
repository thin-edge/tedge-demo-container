#!/bin/sh

help() {
    echo "
USAGE
    $0 <service_name> [--attempts <int>]

FLAGS
    --attempts <int>      Total number of attempts to try before giving up
    --mqtt-host <string>    MQTT broker host. If tedge is installed then it will be used to detect the settings
    --mqtt-port <int>       MQTT broker port. If tedge is installed then it will be used to detect the settings

EXAMPLES
    $0 tedge-agent
    # Wait until the tedge-agent service is healthy

    $0 tedge-agent --attempts 5
    # Wait until the tedge-agent service is healthy and give up after 5 attempts

    $0 mosquitto-c8y-bridge
    # Wait until the mosquitto c8y bridge is healthy (connected)

    $0 tedge-mapper-c8y
    # Wait until the tedge-mapper-c8y service is healthy
    "
}

log() {
    echo "$(date +'%Y-%m-%dT%H:%M:%S%z ') INFO $*" >&2
}

wait_for_healthy() {
    ATTEMPTS=2
    MQTT_HOST=127.0.0.1
    MQTT_PORT=1883
    NAME=
    TOPIC=

    while [ $# -gt 0 ]; do
        case "$1" in
            --attempts)
                ATTEMPTS="$2"
                shift
                ;;
            --mqtt-host)
                MQTT_HOST="$2"
                shift
                ;;
            --mqtt-port)
                MQTT_PORT="$2"
                shift
                ;;
            *)
                if [ -z "$TOPIC" ]; then
                    NAME="$1"
                    TOPIC="tedge/health/$NAME"
                else
                    log "Unknown option: $1"
                fi
                ;;
        esac
        shift
    done

    log "Checking health endpoint status"

    # Get MQTT settings
    if [ -z "$MQTT_HOST" ]; then
        if command -v tedge >/dev/null 2>&1; then
            MQTT_HOST=$(tedge config get mqtt.client.host)
        else
            MQTT_HOST=127.0.0.1
        fi
    fi
    if [ -z "$MQTT_PORT" ]; then
        if command -v tedge >/dev/null 2>&1; then
            MQTT_PORT=$(tedge config get mqtt.client.port)
        else
            MQTT_PORT=1883
        fi
    fi

    i=0

    while [ "$ATTEMPTS" = 0 ] || [ "$i" -ge "$ATTEMPTS" ]; do
        sleep 1
        i=$((i+1))
        SERVICE_STATUS=$(mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC" -C 1 | xargs ||:)
        case "$SERVICE_STATUS" in
            *'"status":"up"'*)
                break
                ;;
            1)
                break
                ;;
            *)
                log "$NAME is down"
                ;;
        esac
    done

    log "$NAME is up"
}

wait_for_healthy "$@"

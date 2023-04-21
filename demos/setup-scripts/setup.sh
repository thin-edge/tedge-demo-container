#!/bin/bash

set -e

#
# helpers
#
info () { echo "INFO  $*" >&2; }
warn () { echo "WARN  $*" >&2; }
error () { echo "ERROR $*" >&2; }

create_firmware () {
    local name="$1"
    local device_type="$2"
    c8y firmware get --id "$name" --silentStatusCodes 404 ||
        c8y firmware create --name "$name" --deviceType "$device_type"
}

create_firmware_version () {
    local name="$1"
    local version="$2"
    local url="$3"
    c8y firmware versions get --firmware "$name" --id "$version" --silentStatusCodes 404 ||
        c8y firmware versions create --firmware "$name" --version "$version" --url "$url"
}

create_software () {
    local name="$1"
    c8y software get --id "$name" --silentStatusCodes 404 ||
        c8y software create --name "$name"
}

create_software_version () {
    local name="$1"
    local version="$2"
    local url="$3"
    c8y software versions get --software "$name" --id "$version" --silentStatusCodes 404 ||
        c8y software versions create --software "$name" --version "$version" --url "$url"
}


create_config_repository_entries() {
    info "Creating config repositories entries"
    local name="$1"
    local config_type="$2"
    local description="$3"
    local file="$4"

    CONFIG_ID=$(c8y configuration list --name "$name" --configurationType "$config_type" --select id -o csv)

    if [ -n "$CONFIG_ID" ]; then
        c8y configuration get --id "$CONFIG_ID"
        return 
    fi

    if [ -f "$file" ]; then
        c8y configuration create --name "$name" --configurationType "$config_type" --description "$description" --file "$file"
    else
        c8y configuration create --name "$name" --configurationType "$config_type" --description "$description" --url "$file"
    fi
}

create_remote_access_config() {
    local device_id="$1"

    # Lookup device (supports both name and id lookup)
    DEVICE_ID=$(c8y devices get --id "$device_id" --select id -o csv)

    if [ -z "$DEVICE_ID" ]; then
        warn "Could not find device: $device_id"
        return
    fi

    # Get existing config (only add if it is not existing)
    EXISTING_CONFIGURATIONS=$(c8y api GET "/service/remoteaccess/devices/$DEVICE_ID/configurations" --select name -o csv)
    info "Existing configurations: $EXISTING_CONFIGURATIONS"

    if [[ "$EXISTING_CONFIGURATIONS" != *passthrough* ]]; then
        # PASSTHROUGH
        c8y api POST "/service/remoteaccess/devices/${DEVICE_ID}/configurations" --template '
{
    "hostname": "127.0.0.1",
    "port": 22,
    "protocol": "PASSTHROUGH",
    "credentialsType": "NONE",
    "name": "passthrough"
}
    '
    else
        info "Device already has the 'passthrough' endpoint configured. deviceID=$DEVICE_ID"
    fi

    # (Web) SSH
    if [[ "$EXISTING_CONFIGURATIONS" != *webssh* ]]; then
        c8y api POST "/service/remoteaccess/devices/${DEVICE_ID}/configurations" --template '
{
    "hostname": "127.0.0.1",
    "port": 22,
    "protocol": "SSH",
    "credentialsType": "USER_PASS",
    "name": "webssh",
    "username": "iotadmin",
    "password": "iotadmin"
}
    '
    else
        info "Device already has the 'webssh' endpoint configured. deviceID=$DEVICE_ID"
    fi
}

main() {
    local DEVICE_ID=
    if [ $# -gt 0 ]; then
        DEVICE_ID="$1"
    fi

    # firmware (for child devices)
    create_firmware "child-iot-linux" "thin-edge.io-child"
    create_firmware_version "child-iot-linux" "1.0.0" "https://example.com"
    create_firmware_version "child-iot-linux" "2.0.0" "https://example.com"

    # software
    create_software "c8y-command-plugin"
    create_software_version "c8y-command-plugin" "latest::apt" " "
    create_software_version "c8y-command-plugin" "latest::apt" " "

    create_software "device-registration-server"
    create_software_version "device-registration-server" "latest::apt" " "

    create_software "vim-tiny"
    create_software_version "vim-tiny" "latest::apt" " "

    # configuration
    echo -e "log_dest syslog\nlog_type warning" > "tmp-config.conf"
    create_config_repository_entries "Production settings" "mosquitto.conf" "mosquitto production logging settings" "./tmp-config.conf"

    echo -e "log_dest syslog\nlog_type debug" > "tmp-config.conf"
    create_config_repository_entries "Debug settings" "mosquitto.conf" "mosquitto debug logging settings" "./tmp-config.conf"
    rm -f tmp-config.conf

    # device setup (if provided by the user)
    if [ -n "$DEVICE_ID" ]; then
        create_remote_access_config "$DEVICE_ID"
    fi
}

if ! command -v c8y >/dev/null 2>&1; then
    error "The setup script requires c8y (go-c8y-cli) to be installed. Please install it and try again"
    exit 1
fi

# Disable all prompts
export CI=${CI:-true}

main "$@"

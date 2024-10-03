#!/bin/sh
set -e

show_usage() {
    echo "
DESCRIPTION
    Bootstrap thin-edge.io.

USAGE

    $0 [VERSION]

FLAGS
    WORKFLOW FLAGS
    --connect/--no-connect                  Connect the mapper. Provide the type of mapper via '--mapper <name>'. Default True
    --mapper <name>                         Name of the mapper to use when connecting (if user has specified the --connect option).
                                            Defaults to 'c8y'. Currently only c8y works.
    --bootstrap                             Force bootstrapping/re-bootstrapping of the device

    DEVICE FLAGS
    --device-id <name>                      Use a specific device-id. A prefix will be added to the device id
    --random                                Use a random device-id. This will override the --device-id flag value
    --prefix <prefix>                       Device id prefix to add to the device-id or random device id. Defaults to 'tedge_'

    CUMULOCITY FLAGS
    --c8y-url <host>                        Cumulocity url, e.g. 'mydomain.c8y.example.io'
    --c8y-user <username>                   Cumulocity username (required when a new device certificate is created)

    MISC FLAGS
    --prompt/--no-prompt                    Set if the script should prompt the user for input or not. By default prompts
                                            will be disabled on non-interactive shells
    --help/-h                               Show this help

EXAMPLES
    sudo -E $0
    # Bootstrap thin-edge.io using the default settings

    sudo -E $0 --device-id mydevice --bootstrap
    # Force bootstrapping using a given device id

    sudo -E $0 --device-id mydevice --bootstrap --prefix ''
    # Bootstrap with a device name without the default prefix

    sudo -E $0 --random --bootstrap
    # Force bootstrapping using a random device id
    "
}

fail () { echo "$1" >&2; exit 1; }
warning () { echo "$1" >&2; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

parse_domain() {
    echo "$1" | sed -E 's|^.*://||g' | sed -E 's|/$||g'
}

banner() {
    echo
    echo "----------------------------------------------------------"
    echo "$1"
    echo "----------------------------------------------------------"
}

# Defaults
DEVICE_ID=${DEVICE_ID:-}
BOOTSTRAP=${BOOTSTRAP:-}
CONNECT=${CONNECT:-1}
MAX_CONNECT_ATTEMPTS=${MAX_CONNECT_ATTEMPTS:-2}
TEDGE_MAPPER=${TEDGE_MAPPER:-c8y}
USE_RANDOM_ID=${USE_RANDOM_ID:-0}
SHOULD_PROMPT=${SHOULD_PROMPT:-1}
CAN_PROMPT=0
UPLOAD_CERT_WAIT=${UPLOAD_CERT_WAIT:-1}
TEST_USER=${TEST_USER:-iotadmin}
PREFIX=${PREFIX:-tedge_}
C8Y_BASEURL=${C8Y_BASEURL:-}
BOOTSTRAP_POSTINST_DIR="${BOOTSTRAP_POSTINST_DIR:-/etc/bootstrap/post.d}"


get_debian_arch() {
    arch=
    if command_exists dpkg; then
        arch=$(dpkg --print-architecture)
    else
        arch=$(uname -m)
        case "$arch" in
            armv7*|armv6*)
                arch="armhf"
                ;;

            aarch64|arm64)
                arch="arm64"
                ;;

            x86_64|amd64)
                arch="amd64"
                ;;

            *)
                fail "Unsupported architecture. arch=$arch. This script only supports: [armv6l, armv7l, aarch64, x86_64]"
                ;;
        esac
    fi

    echo "$arch"
}

generate_device_id() {
    #
    # Generate a device id
    # Either use a raond device, or the device's hostname
    #
    if [ "$USE_RANDOM_ID" = "1" ]; then
        if [ -n "$DEVICE_ID" ]; then
            echo "Overriding the non-empty DEVICE_ID variable with a random name" >&2
        fi

        RANDOM_ID=
        if [ -e /dev/urandom ]; then
            RANDOM_ID=$(head -c 128 /dev/urandom | md5sum | head -c 10)
        elif [ -e /dev/random ]; then
            RANDOM_ID=$(head -c 128 /dev/random | md5sum | head -c 10)
        fi

        if [ -n "$RANDOM_ID" ]; then
            DEVICE_ID="${PREFIX}${RANDOM_ID}"
        else
            warning "Could not generate a random id. Check if /dev/random is available or not"
        fi
    fi

    if [ -n "$DEVICE_ID" ]; then
        echo "$DEVICE_ID"
        return
    fi

    if [ -n "$HOSTNAME" ]; then
        echo "${PREFIX}${HOSTNAME}"
        return
    fi
    if [ -n "$HOST" ]; then
        echo "${PREFIX}${HOST}"
        return
    fi
    echo "${PREFIX}unknown-device"
}

check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run as root or using sudo"
        show_usage
        exit 1
    fi
}

# ---------------------------------------
# Argument parsing
# ---------------------------------------
while [ $# -gt 0 ]
do
    case "$1" in
        # ----------------------
        # Bootstrap
        # ----------------------
        # Device id options
        --device-id)
            DEVICE_ID="$2"
            shift
            ;;

        --prefix)
            PREFIX="$2"
            shift
            ;;
        --random)
            USE_RANDOM_ID=1
            ;;

        --bootstrap)
            BOOTSTRAP=1
            ;;

        --no-bootstrap)
            BOOTSTRAP=0
            ;;

        # ----------------------
        # Connect mapper
        # ----------------------
        --connect)
            CONNECT=1
            ;;
        --no-connect)
            CONNECT=0
            ;;

        # Preferred mapper
        --mapper)
            TEDGE_MAPPER="$2"
            shift
            ;;
        
        # Cumulocity settings
        --c8y-user)
            C8Y_USER="$2"
            shift
            ;;
        --c8y-url)
            C8Y_BASEURL="$2"
            shift
            ;;

        # ----------------------
        # Misc
        # ----------------------
        # Should prompt for use if information is missing?
        --prompt)
            SHOULD_PROMPT=1
            ;;
        --no-prompt)
            SHOULD_PROMPT=0
            ;;

        --help|-h)
            show_usage
            exit 0
            ;;
        
        *)
            POSITIONAL_ARGS="$1"
            ;;
    esac
    shift
done

set -- "$POSITIONAL_ARGS"

# ---------------------------------------
# Initializing
# ---------------------------------------
banner "Initializing"

#
# Detect settings
if command_exists tedge; then
    if [ -z "$C8Y_BASEURL" ]; then
        C8Y_BASEURL=$( tedge config list | grep "^c8y.url=" | sed 's/^c8y.url=//' )    
    fi

    if [ -z "$DEVICE_ID" ]; then
        DEVICE_ID=$( tedge config list | grep "^device.id=" | sed 's/^device.id=//' )
    fi

    # Detect if bootstrapping is required or not?
    if [ -z "$BOOTSTRAP" ]; then
        # If connection already exists, then assume bootstrapping does not need to occur again
        # If already connected, then stick with using the same certificate
        if tedge connect "$TEDGE_MAPPER" --test >/dev/null 2>&1; then
            echo "No need for bootstrapping as $TEDGE_MAPPER mapper is already connected. You can force bootstrapping using either --bootstrap or --clean flags"
            BOOTSTRAP=0
        fi
    fi
fi

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(generate_device_id)
fi

if [ -z "$BOOTSTRAP" ]; then
    BOOTSTRAP=1
fi

#
# Detect if the shell is running in interactive mode or not
if [ -t 0 ]; then
    CAN_PROMPT=1
else
    CAN_PROMPT=0
fi


# ---------------------------------------
# Install helpers
# ---------------------------------------
stop_services() {
    if command_exists systemctl; then
        sudo systemctl stop tedge-agent >/dev/null 2>&1 || true
        sudo systemctl stop tedge-mapper-c8y >/dev/null 2>&1 || true
    fi
}

prompt_value() {
    user_text="$1"
    value="$2"

    if [ "$SHOULD_PROMPT" = 1 ] && [ "$CAN_PROMPT" = 1 ]; then
        printf "\n%s (%s): " "$user_text" "${value:-not set}" >&2
        read -r user_input
        if [ -n "$user_input" ]; then
            value="$user_input"
        fi
    fi
    echo "$value"
}

bootstrap_c8y() {
    # If bootstrapping is called, then it assumes the full bootstrapping
    # needs to be done.

    # Force disconnection of mapper before setting url
    sudo tedge disconnect "$TEDGE_MAPPER" >/dev/null 2>&1 || true

    DEVICE_ID=$(prompt_value "Enter the device.id" "$DEVICE_ID")

    # Remove existing certificate if it does not match
    if tedge cert show >/dev/null 2>&1; then
        echo "Removing existing device certificate"
        sudo tedge cert remove
    fi

    echo "Creating certificate: $DEVICE_ID"
    sudo tedge cert create --device-id "$DEVICE_ID"

    # Cumulocity URL
    C8Y_BASEURL=$(prompt_value "Enter the Cumulocity IoT url" "$C8Y_BASEURL")

    # Normalize url, by stripping url schema
    if [ -n "$C8Y_BASEURL" ]; then
        C8Y_BASEURL=$(parse_domain "$C8Y_BASEURL")
    fi

    echo "Setting c8y.url to $C8Y_BASEURL"
    sudo tedge config set c8y.url "$C8Y_BASEURL"

    C8Y_USER=$(prompt_value "Enter your Cumulocity user" "$C8Y_USER")

    if [ -n "$C8Y_USER" ]; then
        echo "Uploading certificate to Cumulocity using tedge"
        if [ -n "$C8Y_PASSWORD" ]; then
            C8YPASS="$C8Y_PASSWORD" tedge cert upload c8y --user "$C8Y_USER"
        else
            echo ""
            tedge cert upload c8y --user "$C8Y_USER"
        fi
    else
        fail "When manually bootstrapping you have to upload the certificate again as the device certificate is recreated"
    fi

    # Grace period for the server to process the certificate
    # but it is not critical for the connection, as the connection
    # supports automatic retries, but it can improve the first connection success rate
    sleep "$UPLOAD_CERT_WAIT"
}

connect_mappers() {
    # retry connection attempts
    sudo tedge disconnect "$TEDGE_MAPPER" || true

    CONNECT_ATTEMPT=0
    while true; do
        CONNECT_ATTEMPT=$((CONNECT_ATTEMPT + 1))
        if sudo tedge connect "$TEDGE_MAPPER"; then
            break
        else
            if [ "$CONNECT_ATTEMPT" -ge "$MAX_CONNECT_ATTEMPTS" ]; then
                echo "Failed after $CONNECT_ATTEMPT connection attempts. Giving up"
                exit 2
            fi
        fi

        echo "WARNING: Connection attempt failed ($CONNECT_ATTEMPT of $MAX_CONNECT_ATTEMPTS)! Retrying to connect in 2s"
        sleep 2
    done
}

display_banner_c8y() {
    echo
    echo "----------------------------------------------------------"
    echo "Device information"
    echo "----------------------------------------------------------"
    echo ""
    echo "tedge.version:   $(tedge --version 2>/dev/null | tail -1 | cut -d' ' -f2)"
    echo "device.id:       ${DEVICE_ID}"
    DEVICE_SEARCH=$(echo "$DEVICE_ID" | sed 's/-/*/g')
    DISPLAY_URL=$(echo "$C8Y_BASEURL" | sed -E 's|^https?://||g')
    echo "Cumulocity IoT:  https://${DISPLAY_URL}/apps/devicemanagement/index.html#/assetsearch?filter=*${DEVICE_SEARCH}*"
    echo ""
    echo "----------------------------------------------------------"    
}

main() {
    # ---------------------------------------
    # Bootstrap
    # ---------------------------------------
    if [ "$BOOTSTRAP" = 1 ]; then
        banner "Bootstrapping device"
        # Check if tedge is installed before trying to bootstrap
        if ! command_exists tedge; then
            fail "Can not bootstrap as tedge is not installed"
        fi

        bootstrap_c8y
    fi

    # ---------------------------------------
    # Connect
    # ---------------------------------------
    if [ "$CONNECT" = 1 ]; then
        banner "Connecting mapper"
        connect_mappers
    fi

    # ---------------------------------------
    # Post setup
    # ---------------------------------------
    # Run optional post bootstrap scripts
    if [ -d "$BOOTSTRAP_POSTINST_DIR" ]; then
        for script in "$BOOTSTRAP_POSTINST_DIR"/*.sh; do
            if [ -x "$script" ]; then
                echo "Running post bootstrap script: $script"
                "$script"
            else
                echo "Found post bootstrap script but it is not executable: file=$script"
            fi
        done
    fi

    # use startup notifier to send the startup message after bootstrapping to indicate that thin-edge.io is up and running
    sudo systemctl restart startup-notifier >/dev/null 2>&1 ||:

    if [ "$BOOTSTRAP" = 1 ] || [ "$CONNECT" = 1 ]; then
        display_banner_c8y
    fi
}

main

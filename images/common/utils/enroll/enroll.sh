#!/bin/sh
set -e

INHERIT_ENV=${INHERIT_ENV:-1}

OLD_PWD="$(pwd)"
cd /etc

while [ $# -gt 0 ]; do
    case "$1" in
        --inherit-env)
            INHERIT_ENV=1
            ;;
        --no-inherit-env)
            INHERIT_ENV=0
            ;;
        --provisioner-password-file)
            PROVISION_PASSWORD_FILE="$2"
            shift
            ;;
    esac
    shift
done

if [ "$INHERIT_ENV" = 1 ]; then
    # Create env file from PID 1
    # (as this is the old service which inherits the container environment variables)
    echo "Loading environment from PID 1"
    tr '\0' '\n' </proc/1/environ \
    | grep -v "^\(_\|HOME\|PATH\|TERM\|HOSTNAME\|PWD\|SHLVL\)=" | tee > /etc/container.env

    # Load env
    # shellcheck disable=SC1091
    . /etc/container.env
fi


PROVISION_PASSWORD="${PROVISION_PASSWORD:-}"
PROVISION_PASSWORD_FILE=${PROVISION_PASSWORD_FILE:-/etc/provisioner_password}
if [ -n "$PROVISION_PASSWORD" ]; then
    printf -- '%s' "$PROVISION_PASSWORD" > "$PROVISION_PASSWORD_FILE"
    chmod 600 "$PROVISION_PASSWORD_FILE"
fi

enroll_device() {
    # Enable downloading of root cert (this can be trusted when running in a controlled container env)
    if [ -f "$PROVISION_PASSWORD_FILE" ]; then
        /usr/bin/step-ca-admin.sh enroll "$(hostname)" \
            --ca-url https://tedge:8443 \
            --allow-insecure-root \
            --provisioner-password-file "$PROVISION_PASSWORD_FILE"
    else
        /usr/bin/step-ca-admin.sh enroll "$(hostname)" \
        --ca-url https://tedge:8443 \
        --allow-insecure-root
    fi
}

while :; do
    if enroll_device; then
        echo "Enrollment was successful"
        exit 0
    fi
    sleep 2
done

# restore previous working directory
cd "$OLD_PWD"

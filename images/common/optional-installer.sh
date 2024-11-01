#!/bin/sh

set -e

TEST_USER=${TEST_USER:-iotadmin}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_docker_cli() {
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin

    # create systemd-tmpfiles config to create a symlink for docker to the podman socket
    # which allows using docker and docker compose without having to set the DOCKER_HOST variable
    # Source: podman-docker debian package
    echo 'L+  %t/docker.sock   -    -    -     -   %t/podman/podman.sock' | tee /usr/lib/tmpfiles.d/podman-docker-socket.conf
    systemd-tmpfiles --create podman-docker.conf >/dev/null || true
}

install_container_management () {
    # Install with all recommended packages as this is simplier to maintain
    # Note: Use podman instead of docker-ce as docker-ce at build time fails. See https://github.com/docker/cli/issues/4807
    mkdir -p /etc/containers/
    touch /etc/containers/nodocker
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        podman \
        podman-compose \
        tedge-container-plugin \
        unzip

    install_docker_cli
}

configure_users() {
    if [ -n "$TEST_USER" ]; then
        if ! id -u "$TEST_USER" >/dev/null 2>&1; then
            sudo useradd -ms /bin/bash "${TEST_USER}" && echo "${TEST_USER}:${TEST_USER}" | sudo chpasswd && sudo adduser "${TEST_USER}" sudo
        fi
    fi

    echo "Setting sudoers.d config"
    if [ ! -f /etc/sudoers.d/all ]; then
        sudo sh -c "echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/all"
    fi

    echo "Add tedge to the admin group to give it access to monitoring files"
    usermod -a -G adm tedge ||:

    if [ ! -f /etc/sudoers.d/tedge ]; then
        sudo sh -c "echo 'tedge  ALL = (ALL) NOPASSWD: /usr/bin/tedge, /usr/bin/tedge-write /etc/*, /etc/tedge/sm-plugins/[a-zA-Z0-9]*, /bin/sync, /sbin/init, /bin/systemctl, /bin/journalctl, /sbin/shutdown, /usr/bin/on_shutdown.sh' > /etc/sudoers.d/tedge"
    fi
}

configure_services() {
    if command_exists systemctl; then
        if sudo systemctl list-unit-files ssh.service >/dev/null >&2; then
            sudo systemctl enable ssh.service
        fi

        if sudo systemctl list-unit-files tedge-mapper-collectd.service >/dev/null >&2; then
            sudo systemctl enable tedge-mapper-collectd.service
        fi
    fi
}

main() {
    configure_users
    configure_services
    install_container_management
}

main

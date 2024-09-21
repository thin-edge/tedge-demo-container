#!/bin/sh

set -e

TEST_USER=${TEST_USER:-iotadmin}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_container_management () {
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin \
        tedge-container-plugin

    # Disable services to prevent from starting too early
    # before thin-edge has been registered
    if command -v systemctl; then
        echo "Disabling tedge-container-monitor"
        systemctl disable tedge-container-monitor
    fi
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
        sudo systemctl enable ssh
        sudo systemctl enable tedge-mapper-collectd
    fi
}

main() {
    configure_users
    configure_services
    install_container_management
}

main

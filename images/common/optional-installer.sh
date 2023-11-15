#!/bin/sh

set -e

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

main() {
    install_container_management
}

main

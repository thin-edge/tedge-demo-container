#!/bin/sh

set -e

TEST_USER=${TEST_USER:-iotadmin}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_container_management () {
    # Install with all recommended packages as this is simpler to maintain
    # Note: Use podman instead of docker-ce as docker-ce fails at build time. See https://github.com/docker/cli/issues/4807
    mkdir -p /etc/containers/
    touch /etc/containers/nodocker
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        podman \
        podman-compose \
        tedge-container-plugin-ng

    # create systemd-tmpfiles config to create a symlink for docker to the podman socket
    # which allows using docker and docker compose without having to set the DOCKER_HOST variable
    # Source: podman-docker debian package
    echo 'L+  %t/docker.sock   -    -    -     -   %t/podman/podman.sock' | tee /usr/lib/tmpfiles.d/podman-docker-socket.conf
    systemd-tmpfiles --create podman-docker.conf >/dev/null || true
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
        sudo sh -c "echo 'tedge  ALL = (ALL) NOPASSWD: /usr/bin/tedge, /usr/bin/tedge-write /etc/*, /etc/tedge/sm-plugins/[a-zA-Z0-9]*, /bin/sync, /sbin/init, /bin/systemctl, /bin/journalctl, /sbin/shutdown, /usr/bin/on_shutdown.sh, /usr/bin/tedge-container' > /etc/sudoers.d/tedge"
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

set_zsh_defaults() {
    cat <<EOT >> "$1"
autoload -U compinit; compinit
# zsh styling to make the completion menu easier to read and use
zstyle ':completion:*' menu select
# bind shift+tab to reverse menu complete
zmodload zsh/complist
bindkey -M menuselect '^[[Z' reverse-menu-complete

# enable utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
EOT
}

set_bash_defaults() {
    cat <<EOT
. /etc/profile

# enable utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
EOT
}

configure_shells() {    
    # Enable tab completions (note: fish does not require any changes)

    # bash
    echo '[ -f /etc/bash_completion ] && source /etc/bash_completion' >> /etc/profile.d/load_completions.sh
    set_bash_defaults >> ~/.bashrc
    set_bash_defaults >> "/home/$TEST_USER/.bashrc"

    if [ ! -e /etc/bash_completion ]; then
        ln -sf /usr/share/bash-completion/bash_completion /etc/bash_completion
    fi
    
    # zsh
    set_zsh_defaults ~/.zshrc
    set_zsh_defaults "/home/$TEST_USER/.zshrc"
    
    # set default shell to zsh
    # echo "/usr/bin/zsh" >> /etc/shells
    if command -V zsh >/dev/null 2>&1; then
        chsh -s "$(which zsh)"
    fi
}

main() {
    configure_users
    configure_shells
    configure_services
    install_container_management
}

main

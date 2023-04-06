#!/bin/sh

ARCH=$(uname -m)


install() {
    case "$ARCH" in
        aarch64|arm64)
            URL=https://github.com/smallstep/cli/releases/download/v0.23.4/step_linux_0.23.4_arm64.tar.gz
            ;;
        x86_64|amd64)
            URL=https://github.com/smallstep/cli/releases/download/v0.23.4/step_linux_0.23.4_amd64.tar.gz
            ;;
        armv7*)
            URL=https://github.com/smallstep/cli/releases/download/v0.23.4/step_linux_0.23.4_armv7.tar.gz
            ;;
    esac

    wget "$URL"
    sudo dpkg -i step-cli_0.23.1_*.deb
}

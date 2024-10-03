FROM debian:12-slim

# Install
RUN apt-get -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        wget \
        curl \
        gnupg2 \
        sudo \
        apt-transport-https \
        ca-certificates \
        systemd \
        systemd-sysv \
        ssh \
        vim.tiny

# Remove unnecessary systemd services
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/systemd-update-utmp* \
    # Remove policy-rc.d file which prevents services from starting
    && echo "exit 0" | tee /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# Install base files to help with bootstrapping and common settings
WORKDIR /root

# Shutdown handler
COPY common/utils/on_shutdown.sh /usr/bin/on_shutdown.sh

RUN echo "running" \
    # FIXME: remove mosquitto dependency from the tedge package once https://github.com/thin-edge/thin-edge.io/pull/3151 is merged
    && mkdir -p /run/mosquitto \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/tedge-release/setup.deb.sh' | sudo -E bash \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/setup.deb.sh' | sudo -E bash \
    # && wget -O - thin-edge.io/install.sh | sh -s \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        tedge \
        tedge-agent \
        tedge-apt-plugin \
        tedge-inventory-plugin \
    # Disable mosquitto as it is not needed on a child device
    && systemctl disable mosquitto.service \
    && systemctl mask mosquitto.service \
    && rm -rd /run/mosquitto \
    # Disable tedge-agent as it needs to be setup before it can start
    && systemctl disable tedge-agent

COPY child-device-systemd/config/sshd_config /etc/ssh/sshd_config

# Optional installations
COPY common/optional-installer.sh .
RUN ./optional-installer.sh

# Device bootstrap (to run one-off commands on first boot)
COPY common/utils/configure-device/runner.sh /usr/share/configure-device/
COPY common/utils/configure-device/scripts.d/* /usr/share/configure-device/scripts.d/
COPY common/utils/configure-device/configure-device.service /lib/systemd/system/
RUN systemctl enable configure-device.service

COPY child-device-systemd/config/system.toml /etc/tedge/
COPY child-device-systemd/config/tedge.toml /etc/tedge/
COPY common/utils/workflows/firmware_update.toml /etc/tedge/operations/
COPY child-device-systemd/config/tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY child-device-systemd/config/tedge-log-plugin.toml /etc/tedge/plugins/
COPY common/utils/workflows/firmware_update.toml /etc/tedge/operations/

# sudoers
COPY common/config/sudoers.d/* /etc/sudoers.d/

# Reference: https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container#enter_podman
# STOPSIGNAL SIGRTMIN+3 (=37)
STOPSIGNAL 37

CMD ["/lib/systemd/systemd"]

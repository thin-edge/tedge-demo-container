FROM debian:12-slim

ARG VERSION=
ARG TEDGE_CHANNEL=release

ENV INSTALL="false"
# ENV BOOTSTRAP="false"

# Install
RUN apt-get -y update --allow-releaseinfo-change \
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
        # shells
        bash \
        bash-completion \
        zsh \
        fish \
        collectd-core \
        # extra collectd shared libraries
        libmnl0 \
        vim.tiny \
        mosquitto \
        mosquitto-clients

# Note: Avoid using mosquitto 2.0.18 due to a session persistence bug when using `per_listener_settings true
# Only comment out the custom install logic to make it easier to re-enable once the bug is resolved
# See https://github.com/thin-edge/thin-edge.io/issues/3185 for more details
# Install more recent version of mosquitto >= 2.0.18 from debian backports to avoid mosquitto following bugs:
# The mosquitto repo can't be used as it does not included builds for arm64/aarch64 (only amd64 and armhf)
# * https://github.com/eclipse/mosquitto/issues/2604 (2.0.11)
# * https://github.com/eclipse/mosquitto/issues/2634 (2.0.15)
# * https://github.com/eclipse/mosquitto/issues/2618 (2.0.18)
#RUN sh -c "echo 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian bookworm-backports main' > /etc/apt/sources.list.d/debian-bookworm-backports.list" \
#    && apt-get update \
#    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install -t bookworm-backports \
#        mosquitto \
#        mosquitto-clients

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
COPY common/bootstrap.sh /usr/bin/bootstrap.sh

# mqtt-logger
COPY common/utils/mqtt-logger/mqtt-logger.service /lib/systemd/system/
COPY common/utils/mqtt-logger/mqtt-logger /usr/bin/
RUN chmod a+x /usr/bin/mqtt-logger \
    && systemctl enable mqtt-logger.service

# startup-notifier
COPY common/utils/startup-notifier/startup-notifier.service /lib/systemd/system/
COPY common/utils/startup-notifier/startup-notifier /usr/bin/
RUN chmod a+x /usr/bin/startup-notifier \
    && systemctl enable startup-notifier.service

# Shutdown handler
COPY common/utils/on_shutdown.sh /usr/bin/on_shutdown.sh

RUN echo "running" \
    && wget -O - thin-edge.io/install.sh | sh -s -- --channel "$TEDGE_CHANNEL" \
    && systemctl enable collectd \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        tedge-inventory-plugin \
        tedge-command-plugin \
        tedge-monit-setup \
        tedge-nodered-plugin-ng \
        # Local PKI service for easy child device registration
        tedge-pki-smallstep-ca \
    && systemctl disable c8y-firmware-plugin.service \
    && systemctl mask c8y-firmware-plugin.service

COPY common/config/sshd_config /etc/ssh/sshd_config

# Optional installations
COPY common/optional-installer.sh .
RUN ./optional-installer.sh \
    && rm optional-installer.sh

# Podman config
COPY common/config/podman/docker.conf /etc/containers/registries.conf.d/

# Device bootstrap (to run one-off commands on first boot)
COPY common/utils/configure-device/runner.sh /usr/share/configure-device/
COPY common/utils/configure-device/configure-device.service /lib/systemd/system/
RUN mkdir -p /usr/share/configure-device/scripts.d/ \
    && systemctl enable configure-device.service

# Configure device hooks
COPY common/utils/init-pki/init-pki.sh /usr/share/configure-device/scripts.d/30_init-pki
COPY common/utils/set-startup-info /usr/share/configure-device/scripts.d/90_set-startup-info

# Copy bootstrap script hooks
COPY common/config/bootstrap /etc/bootstrap

COPY common/config/tedge-container-plugin.env /etc/tedge-container-plugin/env

COPY common/config/system.toml /etc/tedge/
COPY common/config/tedge.toml /etc/tedge/
COPY common/config/tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY common/config/tedge-log-plugin.toml /etc/tedge/plugins/
COPY common/utils/workflows/firmware_update.toml /etc/tedge/operations/
COPY common/config/collectd.conf /etc/collectd/collectd.conf
COPY common/config/collectd.conf.d /etc/collectd/collectd.conf.d

# Add additional ca certificates used by various Cumulocity instances
COPY common/config/certificates/*.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates -f

# Custom mosquitto config
COPY common/config/mosquitto.conf /etc/mosquitto/conf.d/
COPY common/config/mosquitto-conf/tedge-networkcontainer.conf /etc/tedge/mosquitto-conf/

# sudoers
COPY common/config/sudoers.d/* /etc/sudoers.d/

# Reference: https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container#enter_podman
# STOPSIGNAL SIGRTMIN+3 (=37)
STOPSIGNAL 37

CMD ["/lib/systemd/systemd"]

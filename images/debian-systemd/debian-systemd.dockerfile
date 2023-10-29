FROM debian:11-slim

ARG VERSION=

ENV INSTALL="false"
# ENV BOOTSTRAP="false"

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
        mosquitto \
        mosquitto-clients \
        collectd-core \
        # extra collectd shared libraries
        libmnl0 \
        vim.tiny

# Remove unnecessary systemd services
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp* \
    # Remove policy-rc.d file which prevents services from starting
    && echo "exit 0" | tee /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# Install base files to help with bootstrapping and common settings
WORKDIR /setup
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

# register-operations service
# WORKAROUND: Remove once the firmware_update command can be registered via MQTT
COPY common/utils/register-operations/register-operations.service /lib/systemd/system/
COPY common/utils/register-operations/register-operations.sh /usr/bin/register-operations
RUN systemctl enable register-operations.service

RUN echo "running" \
    && wget -O - thin-edge.io/install.sh | sh -s \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/setup.deb.sh' | sudo -E bash \
    && systemctl enable collectd \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        c8y-command-plugin

# Optional installations
COPY common/optional-installer.sh .
RUN ./optional-installer.sh

# Copy bootstrap script hooks
COPY common/config/bootstrap /etc/bootstrap

COPY common/config/tedge-container-plugin.env /etc/tedge-container-plugin/env

COPY common/config/system.toml /etc/tedge/
COPY common/config/tedge.toml /etc/tedge/
COPY common/config/tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY common/config/tedge-log-plugin.toml /etc/tedge/plugins/
COPY common/config/collectd.conf /etc/collectd/collectd.conf
COPY common/config/collectd.conf.d /etc/collectd/collectd.conf.d

# Custom mosquitto config
COPY common/config/mosquitto.conf /etc/mosquitto/conf.d/

# sudoers
COPY common/config/sudoers.d/* /etc/sudoers.d/

# Reference: https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container#enter_podman
# STOPSIGNAL SIGRTMIN+3 (=37)
STOPSIGNAL 37

CMD ["/lib/systemd/systemd"]

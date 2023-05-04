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
        openrc \
        ssh \
        mosquitto \
        mosquitto-clients \
        collectd-core \
        vim.tiny

# Otherwise mosquitto fails
VOLUME ["/sys/fs/cgroup"]

# openrc settings
COPY common/openrc/rc.conf /etc/

# Install base files to help with bootstrapping and common settings
WORKDIR /setup
COPY common/bootstrap.sh .

# Mosquitto (custom init.d service definition)
COPY common/utils/mosquitto/mosquitto.init /etc/init.d/mosquitto
COPY common/openrc/mosquitto.conf /etc/mosquitto/

# mqtt-logger
COPY common/utils/mqtt-logger/mqtt-logger.init /etc/init.d/mqtt-logger
COPY common/utils/mqtt-logger/mqtt-logger /usr/bin/
RUN chmod a+x /usr/bin/mqtt-logger \
    && rc-update add mqtt-logger

# startup-notifier
COPY common/utils/startup-notifier/startup-notifier.init /etc/init.d/startup-notifier
COPY common/utils/startup-notifier/startup-notifier /usr/bin/
RUN chmod a+x /usr/bin/startup-notifier \
    && rc-update add startup-notifier

# Shutdown handler
COPY common/utils/on_shutdown.sh /usr/bin/on_shutdown.sh

# RUN echo "running" \
    # && ./bootstrap.sh "$VERSION" --install --no-bootstrap --no-connect \
    # && rc-update add collectd \
    # && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        # c8y-command-plugin \ 
        # device-registration-server

# Registration service
# RUN rc-update add device-registration-server

# Optional installations
# COPY common/optional-installer.sh .
# RUN ./optional-installer.sh

COPY common/config/system.toml /etc/tedge/
COPY common/config/tedge.toml /etc/tedge/
COPY common/config/c8y-configuration-plugin.toml /etc/tedge/c8y/
COPY common/config/c8y-log-plugin.toml /etc/tedge/c8y/
COPY common/config/collectd.conf /etc/collectd/collectd.conf
# Custom mosquitto config
COPY common/config/mosquitto.conf /etc/mosquitto/conf.d/

# sudoers
COPY common/config/sudoers.d/* /etc/sudoers.d/

# Reference: https://developers.redhat.com/blog/2019/04/24/how-to-run-systemd-in-a-container#enter_podman
# STOPSIGNAL SIGRTMIN+3 (=37)
STOPSIGNAL 37

ENTRYPOINT ["/sbin/openrc-init"]

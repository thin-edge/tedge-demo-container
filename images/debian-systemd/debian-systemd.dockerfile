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
COPY common/bootstrap.sh .

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
    && ./bootstrap.sh "$VERSION" --install --no-bootstrap --no-connect \
    && systemctl enable collectd \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        c8y-command-plugin \ 
        device-registration-server

# Registration service
RUN systemctl enable device-registration-server.service

# Optional installations
COPY common/optional-installer.sh .
RUN ./optional-installer.sh

# Copy bootstrap script hooks
COPY common/config/bootstrap /etc/boostrap

COPY common/config/tedge-container-plugin.env /etc/tedge-container-plugin/env

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

CMD ["/lib/systemd/systemd"]

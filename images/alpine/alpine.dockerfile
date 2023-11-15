FROM alpine:3.18

# Notes: ca-certificates is required for the initial connection with c8y, otherwise the c8y cert is not trusted
# to test out the connection. But this is only needed for the initial connection, so it seems unnecessary
RUN apk add --no-cache \
    ca-certificates \
    # curl and bash are only required to setup the apk community repo
    curl \
    bash

# Install tedge
RUN curl -sSL thin-edge.io/install.sh | sh -s -- --channel main

# Install additional community plugins
RUN apk add --no-cache \
    c8y-command-plugin \
    tedge-apk-plugin \
    # Set permissions of all files under /etc/tedge
    # FIXME: Remove once the following are solved: https://github.com/thin-edge/thin-edge.io/issues/2452
    && chown tedge:tedge /etc/tedge/operations/c8y

# Add custom config
COPY tedge-log-plugin.toml /etc/tedge/plugins/
COPY tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY system.toml /etc/tedge/

ENV TEDGE_C8Y_PROXY_BIND_ADDRESS 0.0.0.0
ENV TEDGE_HTTP_BIND_ADDRESS 0.0.0.0
ENV TEDGE_MQTT_CLIENT_HOST mosquitto
ENV TEDGE_HTTP_CLIENT_HOST tedge

USER "tedge"
CMD [ "/usr/bin/tedge-agent-v1" ]

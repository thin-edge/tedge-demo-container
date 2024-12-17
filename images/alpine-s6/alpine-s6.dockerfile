FROM alpine:3.18
ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.1.5.0

# Notes: ca-certificates is required for the initial connection with c8y, otherwise the c8y cert is not trusted
# to test out the connection. But this is only needed for the initial connection, so it seems unnecessary
RUN apk update \
    && apk add --no-cache \
        ca-certificates \
        bash \
        curl \
        # GNU sed (to provide the unbuffered streaming option used in the log parsing)
        sed

# Install s6-overlay
# Based on https://github.com/just-containers/s6-overlay#which-architecture-to-use-depending-on-your-targetarch
RUN case ${TARGETARCH} in \
        "amd64")  S6_ARCH=x86_64  ;; \
        "arm64")  S6_ARCH=aarch64  ;; \
        "arm/v6")  S6_ARCH=armhf  ;; \
        "arm/v7")  S6_ARCH=arm  ;; \
    esac \
    && curl https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -L -s --output /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && curl https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz -L -s --output /tmp/s6-overlay-${S6_ARCH}.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz

# Install tedge
RUN curl -sSL thin-edge.io/install.sh | sh -s

# Add custom service definitions
RUN curl -sSL thin-edge.io/install-services.sh | sh -s \
    # Install additional community plugins
    && apk add --no-cache \
        tedge-command-plugin \
        tedge-apk-plugin

# Set permissions of all files under /etc/tedge
# TODO: Can thin-edge.io set permissions during installation?
RUN chown -R tedge:tedge /etc/tedge

# Custom init. scripts
COPY cont-init.d/*  /etc/cont-init.d/

# Add custom config
COPY bootstrap.sh /usr/bin/
COPY tedge-log-plugin.toml /etc/tedge/plugins/
COPY tedge-configuration-plugin.toml /etc/tedge/plugins/

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=30000

ENV TEDGE_C8Y_PROXY_BIND_ADDRESS 0.0.0.0
ENV TEDGE_HTTP_BIND_ADDRESS 0.0.0.0

ENV TEDGE_MQTT_CLIENT_HOST mosquitto
ENV TEDGE_HTTP_CLIENT_HOST tedge
ENV TEDGE_C8Y_PROXY_CLIENT_HOST tedge-mapper-c8y

USER "tedge"
ENTRYPOINT ["/init"]

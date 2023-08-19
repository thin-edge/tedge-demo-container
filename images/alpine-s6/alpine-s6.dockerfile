FROM alpine:3.18
ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.1.5.0

# Notes: ca-certificates is required for the initial connection with c8y, otherwise the c8y cert is not trusted
# to test out the connection. But this is only needed for the initial connection, so it seems unnecessary
RUN apk update \
    && apk add --no-cache \
        ca-certificates \
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
RUN curl -sSL thin-edge.io/install-services.sh | sh -s

# Add custom config
# sudo is still required due to fixed usage within tedge components (e.g. tedge-agent restart etc.)
# https://github.com/thin-edge/thin-edge.io/issues/2096
COPY fake-sudo /usr/bin/sudo

ENV TEDGE_RUN_LOCK_FILES=false
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=30000

USER "tedge"
ENTRYPOINT ["/init"]

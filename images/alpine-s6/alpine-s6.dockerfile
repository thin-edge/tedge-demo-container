# Use alpine 3.16 as it uses the more stable mosquitto 2.0.14 version rather than 2.0.15
# which is included in newer versions of alpine
FROM alpine:3.16
ARG TARGETARCH
ARG TEDGE_VERSION=0.12.0
ARG S6_OVERLAY_VERSION=3.1.5.0

# Notes: ca-certificates is required for the initial connection with c8y, otherwise the c8y cert is not trusted
# to test out the connection. But this is only needed for the initial connection, so it seems unnecessary
RUN apk update \
    && apk add --no-cache \
        ca-certificates \
        mosquitto \
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
RUN case ${TARGETARCH} in \
        "amd64")   TEDGE_ARCH=x86_64-unknown-linux-musl;  ;; \
        "arm64")   TEDGE_ARCH=aarch64-unknown-linux-musl;  ;; \
        "arm/v6")  TEDGE_ARCH=armv7-unknown-linux-musleabihf;  ;; \
        "arm/v7")  TEDGE_ARCH=armv7-unknown-linux-musleabihf;  ;; \
    esac \
    && curl https://github.com/thin-edge/thin-edge.io/releases/download/${TEDGE_VERSION}/tedge_${TEDGE_VERSION}_${TEDGE_ARCH}.tar.gz -L -s --output /tmp/tedge.tar.gz \
    && tar -C /usr/bin/ -xzf /tmp/tedge.tar.gz

# Add custom service definitions
COPY cont-init.d/* /etc/cont-init.d/
COPY s6-rc.d/ /etc/s6-overlay/s6-rc.d/
ADD https://dl.cloudsmith.io/public/thinedge/community/raw/names/tedge-s6overlay/versions/latest/tedge-s6overlay.tar.gz /tmp
RUN tar xzvf /tmp/tedge-s6overlay.tar.gz -C /

# Add pki extension
ADD https://github.com/reubenmiller/tedge-pki/releases/download/0.0.1/tedge-pki-cfssl_0.0.1_noarch.apk /tmp
RUN apk add --allow-untrusted /tmp/tedge-pki-cfssl_*_noarch.apk

# Add custom config
COPY system.toml /etc/tedge/system.toml
COPY mosquitto.conf /etc/mosquitto/mosquitto.conf
COPY on_shutdown.sh /usr/bin/
# sudo is still required due to fixed usage within tedge components (e.g. tedge-agent restart etc.)
# https://github.com/thin-edge/thin-edge.io/issues/2096
COPY fake-sudo /usr/bin/sudo

ENV CONTAINER_USER=tedge
ENV CONTAINER_GROUP=tedge
RUN addgroup -S "$CONTAINER_GROUP" \
    && adduser -g "" -H -D "$CONTAINER_USER" -G "$CONTAINER_GROUP" \
    && mkdir -p /mosquitto/data \
    && chown -R "${CONTAINER_USER}:${CONTAINER_GROUP}" /mosquitto/data

VOLUME "/mosquitto/data"

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV TEDGE_RUN_LOCK_FILES=false
ENV TEDGE_MQTT_BIND_ADDRESS=0.0.0.0
ENV TEDGE_MQTT_BIND_PORT=1883
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=30000

RUN tedge init --user "$CONTAINER_USER" --group "$CONTAINER_GROUP" \
    && c8y-remote-access-plugin --init \
    && chown -R "${CONTAINER_USER}:${CONTAINER_GROUP}" /etc/tedge


USER "$CONTAINER_USER"
ENTRYPOINT ["/init"]

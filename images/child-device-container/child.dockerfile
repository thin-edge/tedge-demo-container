FROM ghcr.io/thin-edge/tedge:latest

USER root
RUN apk add --no-cache \
        curl \
        sudo \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/rsa.B24635C28003430C.key' > /etc/apk/keys/community@thinedge-B24635C28003430C.rsa.pub \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/config.alpine.txt?distro=alpine&codename=v3.8' >> /etc/apk/repositories \
    && apk add --no-cache \
        tedge-apk-plugin \
        tedge-command-plugin \
        tedge-inventory-plugin \
        tedge-pki-smallstep-client \
    && echo "tedge  ALL = (ALL) NOPASSWD: /usr/bin/tedge, /usr/bin/tedge-write /etc/*, /etc/tedge/sm-plugins/[a-zA-Z0-9]*, /bin/sync, /bin/kill" > /etc/sudoers.d/tedge \
    && echo "Defaults        env_keep += \"FEATURES\"" > /etc/sudoers.d/step-ca \
    && echo "tedge  ALL = (ALL) NOPASSWD: /usr/bin/step-ca-admin.sh, /usr/bin/enroll.sh, /usr/sbin/update-ca-certificates" >> /etc/sudoers.d/step-ca \
    # Allow tedge user to control this folder
    && mkdir -p /etc/step-ca \
    && chown -R tedge:tedge /etc/step-ca \
    # Add dummy configuration files
    && echo '{"connectionType":"4G"}' > /etc/modem.json

USER tedge
COPY child-device-container/config/tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY child-device-container/config/tedge-log-plugin.toml /etc/tedge/plugins/
COPY common/utils/enroll/enroll.sh /usr/bin/
COPY child-device-container/entrypoint.sh /app/
COPY common/utils/workflows/firmware_update.toml /etc/tedge/operations/

# Configure device (to run one-off commands on first boot)
COPY common/utils/configure-device/runner.sh /usr/share/configure-device/
COPY common/utils/set-startup-info /usr/share/configure-device/scripts.d/90_set-startup-info

# Inventory scripts
# FIXME: tedge should support this out of the box, but currently the c8y_Agent fragment
# is published by the mapper and not the tedge-agent, so it needs a mapping rule.
COPY common/utils/set-agent-info /usr/share/tedge-inventory/scripts.d/50_c8y_Agent

ENV TEDGE_MQTT_CLIENT_HOST=tedge
ENV TEDGE_HTTP_CLIENT_HOST=tedge
ENV TEDGE_C8Y_PROXY_CLIENT_HOST=tedge
ENV TEDGE_DEVICE_TYPE=thin-edge.io_container

CMD [ "/app/entrypoint.sh" ]

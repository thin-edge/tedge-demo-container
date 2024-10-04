FROM ghcr.io/thin-edge/tedge:latest

USER root
RUN apk add --no-cache \
        curl \
        sudo \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/rsa.B24635C28003430C.key' > /etc/apk/keys/community@thinedge-B24635C28003430C.rsa.pub \
    && curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/config.alpine.txt?distro=alpine&codename=v3.8' >> /etc/apk/repositories \
    && apk add --no-cache \
        tedge-apk-plugin \
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
COPY common/utils/enroll/enroll.sh /usr/bin/
COPY child-device-container/entrypoint.sh /app/
COPY common/utils/workflows/firmware_update.toml /etc/tedge/operations/
ENV TEDGE_MQTT_CLIENT_HOST=tedge
ENV TEDGE_HTTP_CLIENT_HOST=tedge
ENV TEDGE_C8Y_PROXY_CLIENT_HOST=tedge
ENV TEDGE_DEVICE_TYPE=thin-edge.io_container

CMD [ "/app/entrypoint.sh" ]

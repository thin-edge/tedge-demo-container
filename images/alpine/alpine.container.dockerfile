FROM ghcr.io/thin-edge/tedge-main:latest

# Install additional community plugins
USER root
RUN wget -q -O - 'https://dl.cloudsmith.io/public/thinedge/community/rsa.B24635C28003430C.key' > /etc/apk/keys/community@thinedge-B24635C28003430C.rsa.pub \
    && wget -q -O - 'https://dl.cloudsmith.io/public/thinedge/community/config.alpine.txt?distro=alpine&codename=v3.8' >> /etc/apk/repositories \
    && apk add --no-cache \
        c8y-command-plugin \
        tedge-apk-plugin \
        # Containerization defaults
        tedge-container-plugin \
        docker-cli \
        docker-compose

# Add custom config
COPY tedge-log-plugin.toml /etc/tedge/plugins/
COPY tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY system.toml /etc/tedge/

USER "tedge"
CMD [ "/usr/bin/tedge-agent" ]

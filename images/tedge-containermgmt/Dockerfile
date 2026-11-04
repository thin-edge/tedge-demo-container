FROM ghcr.io/thin-edge/tedge:latest

# Install additional community plugins
USER root
RUN apk update \
    && wget -q -O - 'https://dl.cloudsmith.io/public/thinedge/community/rsa.B24635C28003430C.key' > /etc/apk/keys/community@thinedge-B24635C28003430C.rsa.pub \
    && wget -q -O - 'https://dl.cloudsmith.io/public/thinedge/community/config.alpine.txt?distro=alpine&codename=v3.8' >> /etc/apk/repositories \
    && apk add --no-cache \
        tedge-apk-plugin \
        # Containerization defaults
        tedge-container-plugin \
        docker-cli \
        docker-compose \
    # Only install tedge-command-plugin when tedge does not provide the shell_execute operation itself
    && if ! tedge config get agent.enable.shell_execute >/dev/null 2>&1; then \
        apk add --no-cache tedge-command-plugin; \
    fi \
    && apk cache clean

# Add custom config
COPY tedge-log-plugin.toml /etc/tedge/plugins/
COPY tedge-configuration-plugin.toml /etc/tedge/plugins/
COPY container-env /etc/tedge-container-plugin/env

USER "tedge"
CMD [ "/usr/bin/tedge-agent" ]

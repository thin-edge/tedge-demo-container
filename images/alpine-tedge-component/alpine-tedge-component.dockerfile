FROM alpine:3.17

# Notes: ca-certificates is required for the initial connection with c8y, otherwise the c8y cert is not trusted
# to test out the connection. But this is only needed for the initial connection, so it seems unnecessary
RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
        ca-certificates \
        sudo

# Copy all binaries to make the image generic
ADD ./bin/*.tar.gz /usr/bin/

VOLUME [ "/device-certs" ]
VOLUME [ "/etc/tedge" ]
VOLUME [ "/var/tedge" ]
VOLUME [ "/var/log/tedge" ]

COPY ./common/configure.sh ./common/entrypoint.sh ./common/bootstrap.sh ./common/health_check.sh /usr/bin/
# HACK: Initialize the file systems under /etc/tedge however it will be overridden by the later mounted volume
RUN /usr/bin/configure.sh tedge tedge-agent c8y-configuration-plugin c8y-firmware-plugin c8y-log-plugin \
  # Allow init command to be run by tedge
  # TODO: Remove contraint that different files should be managed by different users. All files in a container should be owned by the process
  && sh -c "echo 'tedge  ALL = (ALL) NOPASSWD:SETENV: /usr/bin/tedge, /usr/bin/tedge-agent --init, /usr/bin/c8y-configuration-plugin --init, /usr/bin/c8y-firmware-plugin --init, /usr/bin/c8y-log-plugin --init, /usr/bin/tedge-mapper --init [a-zA-Z0-9]*' > /etc/sudoers.d/tedge"
USER tedge

# Use healthcheck as a holding pattern to prevent the other
# dependent containers from starting until the bridge has been configured
HEALTHCHECK --interval=5s --timeout=1s --start-period=600s \
  CMD /usr/bin/health_check.sh || exit 1

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD [ "tedge-agent" ]

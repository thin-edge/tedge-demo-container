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

# VOLUME [ "/device-certs" ]
VOLUME [ "/etc/tedge" ]
VOLUME [ "/var/tedge" ]
VOLUME [ "/var/log/tedge" ]

ENV TEDGE_RUN_LOCK_FILES=false

COPY ./common/entrypoint.sh ./common/bootstrap.sh ./common/health_check.sh /usr/bin/
USER tedge

# Use healthcheck as a holding pattern to prevent the other
# dependent containers from starting until the bridge has been configured
HEALTHCHECK --interval=5s --timeout=1s --start-period=600s \
  CMD /usr/bin/health_check.sh || exit 1

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD [ "tedge-agent" ]

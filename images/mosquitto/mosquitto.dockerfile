FROM eclipse-mosquitto:2.0.14

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates sudo

COPY ./mosquitto/mosquitto.conf /mosquitto/config/

ENV INSTALL=false

VOLUME [ "/etc/tedge" ]
VOLUME [ "/device-certs" ]

COPY ./common/bootstrap.sh ./common/configure.sh ./common/entrypoint.sh ./common/health_check.sh /usr/bin/
RUN /usr/bin/configure.sh tedge

# Use healthcheck as a holding pattern to prevent the other
# dependent containers from starting until the bridge has been configured
HEALTHCHECK --interval=5s --timeout=1s --start-period=600s \
  CMD /usr/bin/health_check.sh || exit 1

ENTRYPOINT ["/usr/bin/entrypoint.sh", "mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]

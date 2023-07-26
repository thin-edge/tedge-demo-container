FROM eclipse-mosquitto:2.0.14

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates sudo

COPY ./mosquitto/mosquitto.conf /mosquitto/config/

VOLUME [ "/etc/tedge" ]

# Add dummy healthcheck so that other container can wait for it to start up
HEALTHCHECK --interval=5s --timeout=1s --start-period=600s \
  CMD exit 0

ENTRYPOINT ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]

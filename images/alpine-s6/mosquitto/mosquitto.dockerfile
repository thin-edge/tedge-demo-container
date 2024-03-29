FROM eclipse-mosquitto:2.0.18

COPY mosquitto/mosquitto-entrypoint.sh /entrypoint.sh
COPY mosquitto/mosquitto.conf /mosquitto/config/mosquitto.conf

# Install thin-edge.io, use tedge cli to setup mosquitto
RUN wget -O - thin-edge.io/install.sh | sh -s

ENV TEDGE_MQTT_BIND_ADDRESS=0.0.0.0
ENV TEDGE_MQTT_BIND_PORT=1883

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]

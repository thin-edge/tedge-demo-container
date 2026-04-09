FROM eclipse-mosquitto:2.0.18

COPY mosquitto/mosquitto-entrypoint.sh /entrypoint.sh
COPY mosquitto/mosquitto.conf /mosquitto/config/mosquitto.conf

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]

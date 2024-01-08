FROM ghcr.io/thin-edge/python-tedge-agent:0.0.1

ENV CONNECTOR_TEDGE_HOST=tedge
ENV CONNECTOR_TEDGE_API=http://tedge:8000

COPY config/* /data/config/
COPY tedge-configuration-plugin.json /data/config/

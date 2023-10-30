"""Metric handler"""
import json
import logging
import queue

import psutil

# from paho.mqtt.client import Client
from ..client import TedgeClient

from ..topics import measurement_topic

log = logging.getLogger(__name__)


def collect_metrics(client: TedgeClient, settings: queue.SimpleQueue):
    """Collect metrics about the child device

    The function should be called in a background thread.

    Args:
        client (Client): MQTT Client
        settings (queue.SimpleQueue): Settings queue, which can be used
        to the new interval to the control how often the metrics are
        gathered.
    """
    timeout = 5
    while True:
        # pylint: disable=broad-except
        try:
            try:
                # use a queue to limit how often the collection is run
                timeout = settings.get(timeout=timeout)
            except queue.Empty:
                pass
            log.debug("Checking metrics")
            disk_root_usage = psutil.disk_usage("/").percent
            cpu_usage = psutil.cpu_percent()
            client.mqtt.publish(
                measurement_topic(
                    topic_id=f"device/{client.config.device_id}//",
                    type="resource_usage",
                ),
                json.dumps(
                    {
                        "cpu": {
                            "percent-used": cpu_usage,
                        },
                        "df-root": {
                            "percent-used": disk_root_usage,
                        },
                    }
                ),
            )
        except Exception as ex:
            log.warning("Unexpected error. %s", ex, exc_info=True)

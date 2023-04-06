import logging
import json
import time
import re
import os
import threading
from typing import Any
from paho.mqtt.client import Client, MQTTMessage
from .config import Config
from .topics import health_topic
from .management.worker import Worker, Job
from .management import configuration, firmware
from .messages import JSONMessage

log = logging.getLogger(__file__)


def update_url(url: str, replace_url: str) -> str:
    """Modify the url by replacing any reference to a generic 0.0.0.0
    ip with the real ip address of http server hosted by thin-edge.io

    Args:
        url (str): Url to be modified
    """
    return re.sub(r"^(https?://)?0.0.0.0(:\d+)?", replace_url, url, 1)


class TedgeClient:
    def __init__(self, config: Config) -> None:
        self.mqtt = None
        self.config = config
        self._workers = []
        self.config.device_id = self.get_id()
        self._health_topic = health_topic("connector", self.config.device_id)

    def get_id(self):
        return (
            os.getenv("CONNECTOR_DEVICE_ID")
            or os.getenv("HOSTNAME")
            or os.getenv("HOST")
            or "tedge_child"
        )

    def connect(self):
        """Connect to the thin-edge.io MQTT broker"""

        done = threading.Event()

        def on_connect(_client, _userdata, _flags, result_code):
            if result_code == 0:
                log.info("Connected to MQTT Broker!")
            else:
                log.info("Failed to connect. code=%d", result_code)
            done.set()

        # Don't use a clean session so no messages will go missing
        client = Client(self.config.device_id, clean_session=False)
        client.will_set(self._health_topic, json.dumps({"status": "down"}))
        client.on_connect = on_connect
        client.connect(self.config.tedge.host, self.config.tedge.port)
        client.loop_start()
        done.wait()
        self.mqtt = client

    def bootstrap(self):
        """Bootstrap/register the child device's configuration types with thin-edge.io"""
        # Register device using custom child device registration service
        self.mqtt.publish(f"register/devices/{self.config.device_id}", "")
        time.sleep(5)
        self.mqtt.publish(self._health_topic, json.dumps({"status": "up"}))
        configuration.bootstrap(self.config, self.mqtt)

    def subscribe(self):
        """Subscribe to thin-edge.io child device topics and register
        handlers to respond to different operations.
        """
        # get config handler
        handlers = [
            (
                f"tedge/{self.config.device_id}/commands/req/config_snapshot",
                configuration.on_config_snapshot_request,
            ),
            (
                f"tedge/{self.config.device_id}/commands/req/config_update",
                configuration.on_config_update_request,
            ),
            (
                f"tedge/{self.config.device_id}/commands/req/firmware_update",
                firmware.on_firmware_update_request,
            ),
        ]
        for topic, handler in handlers:
            log.info("Registering worker. topic=%s", topic)
            self.register_worker(topic, handler)

    def register_worker(self, topic: str, target: Job, num_threads: int = 1):
        """Register a worker to handle requests for a specific MQTT topic

        Args:
            topic (str): MQTT topic
            target (Any): Job function to execute for the worker
            num_threads (int, optional): Number of threads. Defaults to 1.
        """
        worker = Worker(target, num_threads=num_threads)
        worker.start()

        def add_job(client, _userdata, message: MQTTMessage):
            log.info("Adding job")
            payload = json.loads(message.payload.decode())
            if isinstance(payload, dict):
                if "url" in payload:
                    payload["url"] = update_url(payload["url"], self.config.tedge.api)

            worker.put(self.config, client, JSONMessage(message.topic, payload))

        self.mqtt.message_callback_add(topic, add_job)
        self.mqtt.subscribe(topic)
        self._workers.append(worker)

    def loop_forever(self):
        self.mqtt.loop_forever()

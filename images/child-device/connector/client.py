"""thin-edge.io client"""
import logging
import json
import time
import re
import os
import threading
from typing import Any
import requests
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
    """Tedge Client

    The tedge client is used to communicate with thin-edge.io via MQTT and HTTP
    """

    def __init__(self, config: Config) -> None:
        self.mqtt = None
        self.config = config
        self._workers = []
        self.config.local_id = self.get_id()

    def get_id(self):
        """Get the id to be used for the connector"""
        return (
            os.getenv("CONNECTOR_DEVICE_ID")
            or os.getenv("HOSTNAME")
            or os.getenv("HOST")
            or "tedge_child"
        )

    def connect(self):
        """Connect to the thin-edge.io MQTT broker"""
        if self.mqtt and self.mqtt.is_connected():
            log.info("MQTT client is already connected")
            return

        done = threading.Event()

        def on_connect(_client, _userdata, _flags, result_code):
            if result_code == 0:
                log.info("Connected to MQTT Broker!")
                done.set()
            else:
                log.info("Failed to connect. code=%d", result_code)

        def on_disconnect(_client: Client, _userdata: Any, result_code: int):
            log.info("Client was disconnected. result_code=%d", result_code)
            client.loop_stop()

        # Don't use a clean session so no messages will go missing
        if self.mqtt is None:
            client = Client(self.config.device_id, clean_session=False)
            client.reconnect_delay_set(10, 120)
            if self.config.device_id:
                client.will_set(
                    health_topic("connector", self.config.device_id),
                    json.dumps({"status": "down"}),
                )
            client.on_connect = on_connect
            client.on_disconnect = on_disconnect
            log.info(
                "Trying to connect to the MQTT broker: host=%s:%s, client_id=%s",
                self.config.tedge.host,
                self.config.tedge.port,
                self.config.device_id,
            )
            self.mqtt = client

        self.mqtt.connect(self.config.tedge.host, self.config.tedge.port)
        self.mqtt.loop_start()

        if not done.wait(30):
            self.mqtt.loop_stop(True)
            raise RuntimeError("Failed to connect successfully to MQTT broker")

    def bootstrap(self):
        """Register extra services once the mqtt client is up
        """
        configuration.bootstrap(self.config, self.mqtt)

    def register(self):
        """Register the child device to thin-edge.io"""
        # NOTE: Use custom service to provide the registration api. In the future this
        # will be deprecated and supported by thin-edge.io.
        response = requests.post(
            f"{self.config.tedge.registration_api}/register",
            json={
                "name": self.config.local_id,
                "supportedOperations": [
                    "c8y_Firmware",
                    "c8y_ConfigurationUpdate",
                    "c8y_DownloadConfigFile",
                ],
            },
            timeout=30,
        )

        response.raise_for_status()
        data = response.json()
        self.config.device_id = data.get("id")
        log.info(
            "Child device has been registered successfully. id=%s, message=%s",
            self.config.device_id,
            data,
        )

        # FIXME: Wait before trying to connect to broker
        time.sleep(5)

    def subscribe(self):
        """Subscribe to thin-edge.io child device topics and register
        handlers to respond to different operations.
        """
        # get config handler
        handlers = [
            (
                f"tedge/{self.config.device_id}/commands/req/config_snapshot/#",
                configuration.on_config_snapshot_request,
            ),
            (
                f"tedge/{self.config.device_id}/commands/req/config_update/#",
                configuration.on_config_update_request,
            ),
            (
                f"tedge/{self.config.device_id}/commands/req/firmware_update/#",
                firmware.on_firmware_update_request,
            ),
        ]
        for topic, handler in handlers:
            log.info("Registering worker. topic=%s", topic)
            self.register_worker(topic, handler)

        # Only register that the child device is ready now
        # Register health check and bootstrap other plugin settings
        log.info("Publishing health endpoint. device=%s, service=connector", self.config.device_id)
        self.mqtt.publish(
            health_topic("connector", self.config.device_id),
            json.dumps({"status": "up"}),
        )

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
        """Block infinitely"""
        self.mqtt.loop_forever()

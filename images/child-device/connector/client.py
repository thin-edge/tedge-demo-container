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
        self.config.local_id = self.get_id()

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
        
        def on_disconnect(_client: Client, userdata: Any, result_code: int):
            log.info("Client was disconnected. result_code=%d", result_code)

        # Don't use a clean session so no messages will go missing
        client = Client(self.config.local_id, clean_session=False)
        if self.config.device_id:
            client.will_set(health_topic("connector", self.config.device_id), json.dumps({"status": "down"}))
        client.on_connect = on_connect
        client.on_disconnect = on_disconnect
        client.connect(self.config.tedge.host, self.config.tedge.port)
        client.loop_start()
        done.wait()
        self.mqtt = client

    def registration(self):
        # connect to the device to get register the device, then reconnect with proper device id

        # Option 1: Use http server to register device

        client = Client(self.config.local_id, clean_session=False)

        registration_done = threading.Event()
        local_id = self.config.local_id
        def on_registration_message(_client: Client, _userdata: Any, message: MQTTMessage):
            try:
                payload_content = message.payload.decode()
                log.info("Received registration response. payload=%s", payload_content)
                data = json.loads(payload_content)
                if data and "id" in data:
                    self.config.device_id = data.get("id")
                log.info("Child device has been registered successfully. id=%s, message=%s", self.config.device_id, data)
                registration_done.set()
            except Exception as ex:
                log.warning("Could not parse registration message. %s", ex)

        # client.on_connect = on_connect
        # client.on_disconnect = on_disconnect
        from paho.mqtt import publish
        from paho.mqtt import subscribe

        subscribe.simple("register/{device_id}/res/registry", msg_count=1)
        # publish.single
        

    def bootstrap(self):
        """Bootstrap/register the child device's configuration types with thin-edge.io"""
        # Wait for device name confirmation
        registration_done = threading.Event()
        local_id = self.config.local_id
        def on_registration_message(_client: Client, _userdata: Any, message: MQTTMessage):
            try:
                payload_content = message.payload.decode()
                log.info("Received registration response. payload=%s", payload_content)
                data = json.loads(payload_content)
                if data and "id" in data:
                    self.config.device_id = data.get("id")
                log.info("Child device has been registered successfully. id=%s, message=%s", self.config.device_id, data)
                registration_done.set()
            except Exception as ex:
                log.warning("Could not parse registration message. %s", ex)
    
        # Register device using custom child device registration service
        registration_topic = f"register/devices/res/{local_id}"
        self.mqtt.message_callback_add(registration_topic, on_registration_message)
        self.mqtt.subscribe(registration_topic)
        self.mqtt.publish(f"register/devices/req/{local_id}", "")
        registration_done.wait()
        self.mqtt.unsubscribe(registration_topic)

        # TODO: Wait for a response on the topic (or should this be supplied by the http interface)
        time.sleep(5)
        self.mqtt.publish(health_topic("connector", self.config.device_id), json.dumps({"status": "up"}))
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

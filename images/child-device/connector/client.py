"""thin-edge.io client"""
import logging
import json
import time
import os
import threading
from typing import Any, List
from paho.mqtt.client import Client, MQTTMessage
from .config import Config
from .topics import health_topic
from .management.worker import Worker, Job
from .management import configuration, firmware
from .messages import JSONMessage
from .management.operation import OperationStatus


log = logging.getLogger(__file__)


class TedgeClient:
    """Tedge Client

    The tedge client is used to communicate with thin-edge.io via MQTT and HTTP
    """

    def __init__(self, config: Config) -> None:
        self.mqtt = None
        self.config = config
        self._workers: List[Worker] = []
        self.config.device_id = self.get_id()
        self._subscriptions = []
        self._connected_once = threading.Event()

    def shutdown(self, worker_timeout: float = 10):
        """Shutdown client including any workers in progress

        Args:
            worker_timeout(float): Timeout in seconds to wait for
                each worker (individually). Defaults to 10.
        """
        if self.mqtt and self.mqtt.is_connected():
            self.mqtt.disconnect()
            self.mqtt.loop_stop(True)

        # Stop all workers
        for worker in self._workers:
            worker.join(worker_timeout if worker_timeout and worker_timeout > 0 else 10)

        # Clear workers
        self._workers = []
        self.mqtt = None

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
        if self.mqtt is not None:
            log.info(
                "MQTT client already exists. connected=%s", self.mqtt.is_connected()
            )
            return

        if self.mqtt is None:
            # Don't use a clean session so no messages will go missing
            client = Client(self.config.device_id, clean_session=False)
            client.reconnect_delay_set(10, 120)
            if self.config.device_id:
                client.will_set(
                    health_topic(
                        topic_id=f"device/{self.config.device_id}/service/connector"
                    ),
                    json.dumps({"status": "down"}),
                )

            def _create_on_connect_callback(done):
                _done = done

                def on_connect(_client, _userdata, _flags, result_code):
                    nonlocal _done
                    if result_code == 0:
                        log.info("Connected to MQTT Broker!")
                        _done.set()
                    else:
                        log.info("Failed to connect. code=%d", result_code)

                return on_connect

            def on_disconnect(_client: Client, _userdata: Any, result_code: int):
                log.info("Client was disconnected. result_code=%d", result_code)

            self._connected_once.clear()
            client.on_connect = _create_on_connect_callback(self._connected_once)
            client.on_disconnect = on_disconnect
            # Enable paho mqtt logs to help with any mqtt connection debugging
            client.enable_logger(log)
            log.info(
                "Trying to connect to the MQTT broker: host=%s:%s, client_id=%s",
                self.config.tedge.host,
                self.config.tedge.port,
                self.config.device_id,
            )

            client.connect(self.config.tedge.host, self.config.tedge.port)
            client.loop_start()

            # Only assign client after .connect call (as it can throw an error if the address is not reachable)
            self.mqtt = client

        if not self._connected_once.wait(30):
            log.warning(
                "Failed to connect successfully after 30 seconds. Continuing anyway"
            )
            # TODO: Should an exception be thrown, or just let paho do the reconnect eventually
            # self.shutdown()
            # raise RuntimeError("Failed to connect successfully to MQTT broker")

    def bootstrap(self):
        """Register extra services once the mqtt client is up"""

        self.mqtt.publish(
            f"te/device/{self.config.device_id}//",
            json.dumps(
                {
                    "@type": "child-device",
                    "name": self.config.device_id,
                    "type": "python-connector",
                }
            ),
            retain=True,
            qos=1,
        )
        # wait for registration to be processed
        time.sleep(5)
        configuration.bootstrap(self.config, self.mqtt)
        firmware.bootstrap(self.config, self.mqtt)

    def subscribe(self):
        """Subscribe to thin-edge.io child device topics and register
        handlers to respond to different operations.
        """
        # get config handler
        handlers = [
            (
                f"te/device/{self.config.device_id}///cmd/config_snapshot/+",
                configuration.on_config_snapshot_request,
            ),
            (
                f"te/device/{self.config.device_id}///cmd/config_update/+",
                configuration.on_config_update_request,
            ),
            (
                # TODO: Update to te/ topic once c8y-firmware-plugin has been updated
                f"tedge/+/commands/req/firmware_update",
                firmware.on_firmware_update_request,
            ),
        ]
        for topic, handler in handlers:
            log.info("Registering worker. topic=%s", topic)
            self.register_worker(topic, handler)

        # Only register that the child device is ready now
        # Register health check and bootstrap other plugin settings
        log.info(
            "Publishing health endpoint. device=%s, service=connector",
            self.config.device_id,
        )
        self.mqtt.publish(
            health_topic(topic_id=f"device/{self.config.device_id}/service/connector"),
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
            if len(message.payload) == 0:
                # Message is being cleared
                return

            payload = json.loads(message.payload.decode())
            status = payload.get("status", "")
            is_legacy = message.topic.startswith("tedge/")
            if not is_legacy and status != OperationStatus.INIT:
                return

            log.info("Adding job")
            worker.put(self.config, client, JSONMessage(message.topic, payload))

        self.mqtt.message_callback_add(topic, add_job)
        self.mqtt.subscribe(topic, qos=2)
        self._workers.append(worker)

    def loop_forever(self):
        """Block infinitely"""
        self.mqtt.loop_forever()

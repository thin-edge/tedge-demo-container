"""Firmware handler"""
import logging
import json
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
import requests
from paho.mqtt.client import Client
from .operation import OperationFlow
from ..config import Config
from ..messages import JSONMessage
from ..topics import event_topic


log = logging.getLogger(__name__)


@dataclass
class FirmwareOperation:
    """Operation data structure"""

    # pylint: disable=invalid-name
    id: str = None
    url: str = None
    attempt: int = None
    name: str = None
    version: str = None
    url: str = None
    sha256: str = None

    @classmethod
    def from_payload(cls, payload):
        """Convert a payload into a typed operation"""
        data = cls()
        for key, value in payload.items():
            if hasattr(data, key):
                setattr(data, key, value)
        return data


def bootstrap(config: Config, client: Client):
    """Bootstrap firmware operation

    Args:
        config (Config): Connection configuration
        client (Client): MQTT client
    """
    # TODO: Currently there is no way to register the c8y_Firmware operation
    # time.sleep(5)
    client.publish(
        f"te/device/{config.device_id}///cmd/firmware_update", "{}", retain=True, qos=1
    )


def on_firmware_update_request(config: Config, client: Client, msg: JSONMessage):
    """Set firmware operation handler"""
    # TODO: replace once firmware_update operation has been ported to the v1 API, e.g. te/+/+/+/+/cmd/firmware_update/+
    is_legacy_topic = msg.topic.startswith("tedge/")
    if is_legacy_topic and not str(msg.topic.split("/")[1]).endswith(
        f":{config.device_id}"
    ):
        # ignore operation as it is not for us
        log.info(f"Ignoring message. device_id=%s, topic=%s", config.device_id, msg.topic)
        return

    payload = FirmwareOperation.from_payload(msg.payload)

    topic = msg.topic
    if is_legacy_topic:
        topic = msg.topic.replace("/req/firmware_update", "/res/firmware_update")

    with OperationFlow(client, topic, payload):
        log.info("Downloading firmware. url=%s", payload.url)
        with tempfile.NamedTemporaryFile(
            prefix=payload.id, delete=False
        ) as target_path:
            # stream download so it does not have to save everything to memory
            with requests.get(
                payload.url, stream=True, timeout=config.firmware.download_timeout
            ) as req:
                req.raise_for_status()
                for chunk in req.iter_content(chunk_size=8192):
                    target_path.write(chunk)

            target_path.close()
            log.info("Firmware file downloaded to: %s", target_path.name)

            start_time = time.monotonic()
            # Optional: Send an event indicating that the actually
            client.publish(
                event_topic(
                    "te", f"device/{config.device_id}//", "firmware_update_start"
                ),
                json.dumps(
                    {
                        "text": f"Applying firmware: {payload.name}={payload.version}",
                        "name": payload.name,
                        "version": payload.version,
                        "time": datetime.now().isoformat() + "Z",
                    }
                ),
            )

            # Add whatever you want to do with the file here!
            # Simulate some work by sleeping
            work_duration = 10
            while True:
                if time.monotonic() - start_time > work_duration:
                    break
                _ = 100 * 100
            # time.sleep(10)

            # Optional: Send an event once the update is done with a duration how long it took
            duration = timedelta(seconds=int(time.monotonic() - start_time))
            client.publish(
                event_topic(
                    "te", f"device/{config.device_id}//", "firmware_update_done"
                ),
                json.dumps(
                    {
                        "text": (
                            f"Finished applying firmware: {payload.name}={payload.version}"
                            f", duration={duration}"
                        ),
                        "name": payload.name,
                        "version": payload.version,
                        "time": datetime.now().isoformat() + "Z",
                    }
                ),
            )

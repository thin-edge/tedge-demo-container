from dataclasses import dataclass
import logging
import json
import os
import shutil
import tempfile
from typing import Dict, Any
import requests
from paho.mqtt.client import Client
from .operation import OperationFlow
from ..config import Config
from ..messages import JSONMessage

log = logging.getLogger(__name__)

CONFIG_TYPE = "c8y-configuration-plugin"


@dataclass
class ConfigurationOperation:
    """Configuration operation"""

    # pylint: disable=too-few-public-methods
    type: str = None
    path: str = None
    url: str = None

    @classmethod
    def from_payload(cls, config: Config, payload: Dict[str, Any]):
        """Convert a payload into a typed operation"""
        data = cls(**payload)
        data.type = data.path if not data.type else data.type
        if data.type == CONFIG_TYPE:
            data.path = config.configuration.path
        return data


def bootstrap(config: Config, client: Client):
    if not os.path.exists(config.configuration.path):
        log.info(
            "Skipping configuration bootstrap as file does not exist. path=%s",
            config.configuration.path,
        )
        return

    log.info("Uploading the config file")
    with open(config.configuration.path, "rb") as file:
        content = file.read()

    url = f"{config.tedge.api}/tedge/file-transfer/{config.device_id}/{CONFIG_TYPE}"
    response = requests.put(
        url, data=content, timeout=config.configuration.upload_timeout
    )
    log.info("url=%s, status_code=%d", url, response.status_code)

    log.info(
        "Setting config_snapshot status for config-type: %s to successful", CONFIG_TYPE
    )
    message_payload = json.dumps(
        {
            "path": "",
            "type": CONFIG_TYPE,
        }
    )
    client.publish(
        f"tedge/{config.device_id}/commands/res/config_snapshot", message_payload
    )


def on_config_snapshot_request(config: Config, client: Client, msg: JSONMessage):
    """Get configuration operation handler"""
    topic = f"tedge/{config.device_id}/commands/res/config_snapshot"
    payload = ConfigurationOperation.from_payload(config, msg.payload)

    with OperationFlow(client, topic, payload):
        if not os.path.exists(payload.path):
            raise FileNotFoundError(f"File was not found. path={payload.path}")

        # Upload the requested file
        log.info(
            "Uploading the config file. url=%s, path=%s", payload.url, payload.path
        )
        with open(payload.path, "rb") as file:
            response = requests.put(
                payload.url, data=file, timeout=config.configuration.upload_timeout
            )
            log.info("url=%s, status_code=%d", payload.url, response.status_code)


def on_config_update_request(config: Config, client: Client, msg: JSONMessage):
    """Set configuration operation handler"""
    topic = f"tedge/{config.device_id}/commands/res/config_update"
    payload = ConfigurationOperation.from_payload(config, msg.payload)

    with OperationFlow(client, topic, payload):
        # Download the config file update from tedge
        log.info("Downloading configuration. url=%s", payload.url)
        response = requests.get(
            payload.url, timeout=config.configuration.download_timeout
        )
        log.debug(
            "response: %s, status_code=%d", response.content, response.status_code
        )

        with tempfile.NamedTemporaryFile(
            prefix=payload.type, delete=False
        ) as target_path:
            log.info("temp_path=%s", target_path.name)
            target_path.write(response.content)
            target_path.close()
            # Replace the existing config file with the updated file downloaded from tedge
            shutil.move(target_path.name, payload.path)

"""Configuration handler to get and set configuration files"""
from dataclasses import dataclass
import logging
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Dict, Any
import requests
from paho.mqtt.client import Client
from .operation import OperationFlow, OperationStatus
from ..config import Config
from ..messages import JSONMessage

log = logging.getLogger(__name__)


@dataclass
class ConfigurationOperation:
    """Configuration operation"""

    # pylint: disable=too-few-public-methods
    status: str = None
    type: str = None
    path: str = None
    remoteUrl: str = None
    tedgeUrl: str = None

    @classmethod
    def from_payload(cls, config: Config, payload: Dict[str, Any]):
        """Convert a payload into a typed operation"""
        data = cls()
        for key, value in payload.items():
            if hasattr(data, key):
                setattr(data, key, value)

        data.type = data.path if not data.type else data.type
        if data.type == config.configuration.type:
            data.path = config.configuration.path
        return data


def bootstrap(config: Config, client: Client):
    """Bootstrap configuration settings by sending the
    available configuration files to thin-edge.io

    Args:
        config (Config): Connection configuration
        client (Client): MQTT client
    """
    if not os.path.exists(config.configuration.path):
        log.info(
            "Skipping configuration bootstrap as file does not exist. path=%s",
            config.configuration.path,
        )
        return

    plugin_config = load_plugin_config(config)

    log.info("Registering support for config_snapshot and config_update")
    cmd_payload = json.dumps(
        {
            # TODO: Read from the types of configuration from file
            "types": sorted(plugin_config.keys()),
        }
    )
    client.publish(
        f"te/device/{config.device_id}///cmd/config_snapshot",
        cmd_payload,
        retain=True,
        qos=1,
    )
    client.publish(
        f"te/device/{config.device_id}///cmd/config_update",
        cmd_payload,
        retain=True,
        qos=1,
    )


def load_plugin_config(config: Config) -> Dict[str, Any]:
    plugin_config = json.loads(
        Path(config.configuration.path).read_text(encoding="utf8")
    )
    data = {
        config.configuration.type: {
            "type": config.configuration.type,
            "path": config.configuration.path,
        },
    }
    for item in plugin_config.get("files", []):
        data[item["type"]] = item
    return data


def on_config_snapshot_request(config: Config, client: Client, msg: JSONMessage):
    """Get configuration operation handler"""
    payload = ConfigurationOperation.from_payload(config, msg.payload)

    if payload.status != OperationStatus.INIT:
        return

    plugin_config = load_plugin_config(config)

    with OperationFlow(client, msg.topic, payload):
        if payload.type not in plugin_config:
            raise RuntimeError(f"Unknown configuration file type. type={payload.type}")

        file_config = plugin_config.get(payload.type)
        path = file_config["path"]

        if not os.path.exists(path):
            raise FileNotFoundError(f"File was not found. path={path}")

        # Upload the requested file
        log.info("Uploading the config file. url=%s, path=%s", payload.tedgeUrl, path)
        with open(path, "rb") as file:
            response = requests.put(
                payload.tedgeUrl, data=file, timeout=config.configuration.upload_timeout
            )
            log.info("url=%s, status_code=%d", payload.tedgeUrl, response.status_code)


def on_config_update_request(config: Config, client: Client, msg: JSONMessage):
    """Set configuration operation handler"""
    payload = ConfigurationOperation.from_payload(config, msg.payload)

    if payload.status != OperationStatus.INIT:
        return

    plugin_config = load_plugin_config(config)

    with OperationFlow(client, msg.topic, payload):
        if payload.type not in plugin_config:
            raise RuntimeError(f"Unknown configuration file type. type={payload.type}")

        file_config = plugin_config.get(payload.type)
        path = file_config["path"]

        # Download the config file update from tedge
        log.info("Downloading configuration. url=%s", payload.tedgeUrl)
        response = requests.get(
            payload.tedgeUrl, timeout=config.configuration.download_timeout
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
            shutil.move(target_path.name, path)

        if payload.type == config.configuration.type:
            log.info("Re-reading plugin configuration")
            bootstrap(config, client)

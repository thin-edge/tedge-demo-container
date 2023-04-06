import os
from dataclasses import dataclass, field
from configparser import ConfigParser


@dataclass
class Configuration:
    download_timeout: float = 600.0
    upload_timeout: float = 600.0
    type: str = "c8y-configuration-plugin"
    path: str = "./c8y-configuration-plugin.toml"


@dataclass
class Firmware:
    download_timeout: float = 600.0


@dataclass
class Tedge:
    host: str = "localhost"
    port: int = 1883
    api: str = "http://localhost:8000"


@dataclass
class Metrics:
    interval: float = 5.0


@dataclass
class Config:
    device_id: str = None

    tedge: Tedge = field(default_factory=Tedge)
    configuration: Configuration = field(default_factory=Configuration)
    firmware: Firmware = field(default_factory=Firmware)
    metrics: Metrics = field(default_factory=Metrics)

    def load_file(self, path: str):
        config = ConfigParser()
        config.read(path, encoding="utf8")

        for section in config.sections():
            if hasattr(self, section):
                prop_section = getattr(self, section)

                for option in config.options(section):
                    if hasattr(prop_section, option):
                        existing_value = getattr(prop_section, option)

                        if isinstance(existing_value, int):
                            new_value = config.getint(section, option)
                        elif isinstance(existing_value, float):
                            new_value = config.getfloat(section, option)
                        elif isinstance(existing_value, bool):
                            new_value = config.getboolean(section, option)
                        else:  # default to string
                            new_value = config.get(section, option)

                        setattr(prop_section, option, new_value)

    def load_env(self):
        prefix = "CONNECTOR_"
        for key, value in os.environ.items():
            if not key.startswith(prefix) or not value:
                continue

            parts = key[len(prefix) :].lower().split("_", maxsplit=1)
            if len(parts) == 2:
                if hasattr(self, parts[0]):
                    section = getattr(self, parts[0])
                    if hasattr(section, parts[1]):
                        setattr(section, parts[1], value)

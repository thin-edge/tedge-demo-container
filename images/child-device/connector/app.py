import logging
import queue
import threading
import os
import time
import sys
from .config import Config
from .client import TedgeClient
from .management.metrics import collect_metrics

# Set sensible logging defaults
log = logging.getLogger()
log.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
log.addHandler(handler)


class App:
    # pylint: disable=too-few-public-methods
    def run(self):
        # pylint: disable=broad-exception-caught
        _queue = queue.SimpleQueue()
        config = Config()

        file = os.getenv("CONNECTOR_SETTINGS", "./config/connector.ini")
        if os.path.exists(file):
            config.load_file(file)
        config.load_env()
        client = TedgeClient(config)

        while True:
            try:
                client.connect()
                client.subscribe()
                client.bootstrap()
                client.register_worker()

                metrics_thread = threading.Thread(
                    target=collect_metrics, args=(client, _queue)
                )
                metrics_thread.start()
                client.loop_forever()
            except ConnectionRefusedError:
                log.info("MQTT broker is not ready yet")
            except KeyboardInterrupt:
                log.info("Exiting...")
                sys.exit(0)
            except Exception as ex:
                log.info("Unexpected error. %s", ex)

            # Wait before trying again
            time.sleep(5)

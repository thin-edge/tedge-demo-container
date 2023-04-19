"""Worker class to process tasks in the background"""
import logging
import queue
import threading
from typing import Any, List, Callable

from paho.mqtt.client import Client
from ..messages import JSONMessage
from ..config import Config

Job = Callable[[Config, Client, JSONMessage], None]


class Worker:
    """Worker thread to process work"""

    def __init__(
        self,
        target: Job,
        num_threads: int = 1,
    ) -> None:
        """
        Args:
            target (worker_func, None]): Callback that will
                 be called on each job received
            num_threads (int, optional): Number of threads to use to
                process the jobs. Defaults to 1.
        """
        self.queue = queue.SimpleQueue()
        self.target = target
        self.name = getattr(target, "__name__", "worker")
        self._num_threads = num_threads
        self._threads: List[threading.Thread] = []
        self._log = logging.getLogger()

    def start(self):
        """Start the background worker threads"""
        for _ in range(self._num_threads):
            thread = threading.Thread(target=self.run, name=self.name)
            thread.start()
            self._threads.append(thread)

    def join(self, timeout: float = None):
        """Send shutdown signal to all workers and wait for them to stop

        Args:
            timeout (float, optional): Timeout in seconds. Defaults to None.
        """
        # Send shutdown signal (empty message)
        for thread in self._threads:
            self.queue.put(None)

        # Wait for threads to exit
        for thread in self._threads:
            thread.join(timeout=timeout)

        self._threads = []

    def put(self, config: Config, client: Any, message: JSONMessage):
        """Add job to queue

        Args:
            client (Client): MQTT Client
            message (MQTTMessage): MQTT Message
        """
        self.queue.put((config, client, message))

    def run(self):
        """Process jobs by reading from the job queue"""
        while True:
            data = self.queue.get()
            if not data:
                self._log.info("Shutting down worker thread")
                break

            config, client, message = data
            self._log.info(
                "%s: new message from queue. message=%s",
                self.name,
                message.payload,
            )
            self.target(config, client, message)

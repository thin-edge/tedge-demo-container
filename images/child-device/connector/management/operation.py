"""Operation utilities"""
import json
import logging
from typing import Any
from paho.mqtt.client import Client

log = logging.getLogger(__name__)


class OperationStatus:
    """Operation statuses"""

    # pylint: disable=too-few-public-methods
    INIT = "init"
    EXECUTING = "executing"
    SUCCESSFUL = "successful"
    FAILED = "failed"


class OperationFlow:
    """Operation flow handler. The class is responsible for handling the operation
    transitions.

    The class will automatically set the operation to successful if no exception
    occur, and set it to failed if any exception occur. The idea it to reliably
    transition the operations statuses and not let the user handle all of the
    scenarios.
    """

    # pylint: disable=too-many-arguments
    def __init__(
        self,
        client: Client,
        topic: str,
        payload: Any = None,
        skip_executing: bool = False,
        exceptions=Exception,
    ) -> None:
        self.client = client
        self.topic = topic
        self.request = payload
        self._skip_executing = skip_executing
        self._exceptions = exceptions

    def executing(self):
        """Transition operation to the executing state"""
        payload = {
            **self.request.__dict__,
            "status": OperationStatus.EXECUTING,
        }
        log.info(
            "Setting %s to %s. topic=%s, payload=%s",
            self.__class__.__name__,
            OperationStatus.EXECUTING,
            self.topic,
            payload,
        )
        self.client.publish(self.topic, json.dumps(payload))

    def finished(self, status: str, reason: str = None):
        """Transition operation to the executing state

        Args:
            status (str): Operation status
            reason (str, optional): Failure reason
        """
        payload = {
            **self.request.__dict__,
            "status": status,
        }
        if reason:
            payload["reason"] = reason

        log.info(
            "Updating %s status. topic=%s, payload=%s",
            self.__class__.__name__,
            self.topic,
            payload,
        )
        self.client.publish(self.topic, json.dumps(payload))

    def __enter__(self):
        # Set operation to executing
        if not self._skip_executing:
            self.executing()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # set operation to either successful or failed
        if exc_type:
            log.warning("Operation failed. %s %s", exc_type, exc_val, exc_info=True)
            self.finished(OperationStatus.FAILED, str(exc_val))
        else:
            self.finished(OperationStatus.SUCCESSFUL)

        return exc_type is not None and issubclass(exc_type, self._exceptions)

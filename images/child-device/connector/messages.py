from dataclasses import dataclass
from typing import Dict, Any


@dataclass
class JSONMessage:
    topic: str
    payload: Dict[str, Any]

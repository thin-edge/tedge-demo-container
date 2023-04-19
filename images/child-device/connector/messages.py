"""Messages"""

from dataclasses import dataclass
from typing import Dict, Any


@dataclass
class JSONMessage:
    """JSON Message"""

    topic: str
    payload: Dict[str, Any]

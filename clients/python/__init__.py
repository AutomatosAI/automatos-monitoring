"""Automatos Monitoring Python Clients — drop-in integrations for any service."""

from .automatos_logging import setup_logging, LogRelayHandler
from .automatos_metrics import setup_metrics
from .automatos_alerts import create_alerts_router

__all__ = [
    "setup_logging",
    "LogRelayHandler",
    "setup_metrics",
    "create_alerts_router",
]

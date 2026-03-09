"""
Log Relay Service — Railway Log Drain → Loki

Receives HTTP log drain webhooks from Railway, transforms them into
Loki's push format, and forwards them to the Loki instance.

Also accepts direct log pushes from services that want structured logging.
"""

import json
import os
import time
from collections import defaultdict

from aiohttp import web, ClientSession, ClientTimeout

LOKI_PUSH_URL = os.environ.get("LOKI_PUSH_URL", "http://loki:3100/loki/api/v1/push")
LOG_RELAY_SECRET = os.environ.get("LOG_RELAY_SECRET", "dev-secret")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
BATCH_INTERVAL_MS = int(os.environ.get("BATCH_INTERVAL_MS", "1000"))
MAX_BATCH_SIZE = int(os.environ.get("MAX_BATCH_SIZE", "100"))

# Lines to drop (health check noise)
DROP_PATTERNS = frozenset([
    "GET /health",
    "GET /api/health",
    "GET /-/healthy",
    "GET /ready",
    "GET /loki/api/v1/ready",
])

# Buffered log entries waiting to be flushed to Loki
_buffer: list[dict] = []
_session: ClientSession | None = None


def _should_drop(message: str) -> bool:
    return any(pattern in message for pattern in DROP_PATTERNS)


def _parse_severity(raw: str) -> str:
    mapping = {
        "debug": "debug",
        "info": "info",
        "warn": "warning",
        "warning": "warning",
        "error": "error",
        "fatal": "critical",
        "critical": "critical",
    }
    return mapping.get(raw.lower(), "info")


def _build_loki_payload(entries: list[dict]) -> dict:
    """Group entries by label set and build Loki push payload."""
    streams: dict[str, list] = defaultdict(list)

    for entry in entries:
        labels = entry.get("labels", {})
        label_key = json.dumps(labels, sort_keys=True)
        ts_ns = str(int(entry.get("timestamp", time.time()) * 1e9))
        streams[label_key].append([ts_ns, entry.get("message", "")])

    return {
        "streams": [
            {
                "stream": json.loads(label_key),
                "values": values,
            }
            for label_key, values in streams.items()
        ]
    }


async def _flush_buffer():
    """Send buffered entries to Loki."""
    global _buffer, _session

    if not _buffer:
        return

    entries = _buffer[:]
    _buffer = []

    payload = _build_loki_payload(entries)

    if _session is None:
        _session = ClientSession(timeout=ClientTimeout(total=10))

    try:
        async with _session.post(
            LOKI_PUSH_URL,
            json=payload,
            headers={"Content-Type": "application/json"},
        ) as resp:
            if resp.status >= 400:
                body = await resp.text()
                print(f"Loki push failed ({resp.status}): {body}")
    except Exception as e:
        print(f"Loki push error: {e}")
        # Re-buffer failed entries (up to max)
        _buffer = (entries + _buffer)[:MAX_BATCH_SIZE * 2]


async def handle_railway_drain(request: web.Request) -> web.Response:
    """Handle Railway HTTP log drain webhook.

    Railway sends JSON arrays of log entries:
    [{"message": "...", "severity": "info", "service": "backend", ...}]
    """
    # Validate shared secret
    secret = request.headers.get("X-Railway-Secret", "")
    if ENVIRONMENT == "production" and secret != LOG_RELAY_SECRET:
        return web.Response(status=401, text="Unauthorized")

    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

    # Railway may send a single object or an array
    entries = body if isinstance(body, list) else [body]

    for entry in entries:
        message = entry.get("message", "")

        if _should_drop(message):
            continue

        service = entry.get("service", entry.get("source", "unknown"))
        severity = _parse_severity(entry.get("severity", entry.get("level", "info")))

        _buffer.append({
            "labels": {
                "job": f"railway-{service}",
                "service": service,
                "level": severity,
                "environment": ENVIRONMENT,
                "source": "railway-drain",
            },
            "message": message,
            "timestamp": time.time(),
        })

    if len(_buffer) >= MAX_BATCH_SIZE:
        await _flush_buffer()

    return web.Response(status=204)


async def handle_direct_push(request: web.Request) -> web.Response:
    """Handle direct log pushes from services.

    Expects JSON:
    {
      "service": "automatos-backend",
      "level": "error",
      "message": "Something failed",
      "extra": {"request_id": "...", "module": "..."}
    }
    """
    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

    entries = body if isinstance(body, list) else [body]

    for entry in entries:
        message = entry.get("message", "")

        if _should_drop(message):
            continue

        service = entry.get("service", "unknown")
        level = _parse_severity(entry.get("level", "info"))
        extra = entry.get("extra", {})

        labels = {
            "job": f"automatos-{service}",
            "service": service,
            "level": level,
            "environment": ENVIRONMENT,
            "source": "direct-push",
        }

        # Add selected extra fields as labels (keep cardinality low)
        if "module" in extra:
            labels["module"] = extra["module"]

        # Include full extra in the log line
        log_line = message
        if extra:
            log_line = f"{message} | {json.dumps(extra)}"

        _buffer.append({
            "labels": labels,
            "message": log_line,
            "timestamp": time.time(),
        })

    if len(_buffer) >= MAX_BATCH_SIZE:
        await _flush_buffer()

    return web.Response(status=204)


async def handle_health(request: web.Request) -> web.Response:
    return web.json_response({
        "status": "healthy",
        "service": "log-relay",
        "buffer_size": len(_buffer),
        "loki_url": LOKI_PUSH_URL,
    })


async def handle_root(request: web.Request) -> web.Response:
    """Root handler — Railway log drain sends GET to verify endpoint."""
    return web.json_response({
        "service": "automatos-log-relay",
        "endpoints": {
            "drain": "POST /drain",
            "push": "POST /push",
            "health": "GET /health",
        },
    })


async def periodic_flush(app: web.Application):
    """Background task to flush buffer periodically."""
    import asyncio
    try:
        while True:
            await asyncio.sleep(BATCH_INTERVAL_MS / 1000)
            await _flush_buffer()
    except asyncio.CancelledError:
        await _flush_buffer()


async def on_startup(app: web.Application):
    import asyncio
    app["flush_task"] = asyncio.create_task(periodic_flush(app))


async def on_cleanup(app: web.Application):
    app["flush_task"].cancel()
    await _flush_buffer()
    if _session is not None:
        await _session.close()


def create_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/", handle_root)
    app.router.add_post("/drain", handle_railway_drain)
    app.router.add_post("/push", handle_direct_push)
    app.router.add_get("/health", handle_health)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    return app


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app = create_app()
    print(f"Log relay starting on port {port}")
    print(f"Loki push URL: {LOKI_PUSH_URL}")
    web.run_app(app, host="0.0.0.0", port=port)

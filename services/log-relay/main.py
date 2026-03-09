"""
Log Relay Service — Structured Log Gateway → Loki

Phase 2: Accepts structured log entries with context, error fingerprints,
and metrics. Promotes bounded fields to Loki labels for fast querying.
Formats log lines as structured JSON for LogQL parsing.

Endpoints:
  POST /push   — Direct push from services (structured)
  POST /drain  — Railway log drain webhooks (raw)
  GET  /health — Health check
  GET  /        — Service info
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
    "GET /metrics",
])

# Fields promoted to Loki labels (bounded cardinality only)
LABEL_FIELDS = frozenset({"service", "level", "environment", "source", "module", "method", "error_type"})

# Max cardinality guard — if a label has too many unique values, stop promoting it
_label_cardinality: dict[str, set] = defaultdict(set)
MAX_LABEL_VALUES = 50

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


def _truncate_module(module: str) -> str:
    """Keep only the top-level module name to limit cardinality.

    'orchestrator.consumers.chatbot.auto' → 'consumers'
    'core.monitoring.automatos_metrics' → 'monitoring'
    """
    parts = module.split(".")
    # Skip 'orchestrator' prefix, take the domain module
    if len(parts) > 1 and parts[0] in ("orchestrator", "core", "api"):
        return parts[1] if len(parts) > 1 else parts[0]
    return parts[0]


def _should_promote_label(key: str, value: str) -> bool:
    """Guard against cardinality explosion."""
    if key not in LABEL_FIELDS:
        return False
    _label_cardinality[key].add(value)
    return len(_label_cardinality[key]) <= MAX_LABEL_VALUES


def _build_structured_log_line(entry: dict) -> str:
    """Format a structured JSON log line for Loki.

    Compact format optimized for LogQL json parsing:
    {"msg":"...", "ctx":{...}, "err":{...}, "dur":123}
    """
    line = {"msg": entry.get("message", "")}

    # Context — shortened keys for log volume efficiency
    ctx = entry.get("context", {})
    if ctx:
        compact_ctx = {}
        key_map = {
            "request_id": "rid",
            "correlation_id": "cid",
            "workspace_id": "ws",
            "user_id": "uid",
            "agent_id": "aid",
            "workflow_id": "wid",
            "run_id": "run",
            "tenant_id": "tid",
            "path": "path",
            "function": "fn",
            "lineno": "line",
            "logger": "log",
            "task_id": "task",
            "model": "model",
        }
        for full_key, short_key in key_map.items():
            val = ctx.get(full_key)
            if val:
                compact_ctx[short_key] = val
        if compact_ctx:
            line["ctx"] = compact_ctx

    # Error info
    error = entry.get("error", {})
    if error:
        compact_err = {}
        if error.get("type"):
            compact_err["type"] = error["type"]
        if error.get("fingerprint"):
            compact_err["fp"] = error["fingerprint"]
        if error.get("stack_hash"):
            compact_err["sh"] = error["stack_hash"]
        if error.get("message"):
            compact_err["msg"] = error["message"][:200]
        if error.get("traceback"):
            compact_err["tb"] = error["traceback"][:2000]
        if compact_err:
            line["err"] = compact_err

    # Duration
    metrics = entry.get("metrics", {})
    if metrics.get("duration_ms"):
        line["dur"] = metrics["duration_ms"]
    if metrics.get("tokens_in"):
        line["tok_in"] = metrics["tokens_in"]
    if metrics.get("tokens_out"):
        line["tok_out"] = metrics["tokens_out"]

    return json.dumps(line, separators=(",", ":"))


def _build_loki_payload(entries: list[dict]) -> dict:
    """Group entries by label set and build Loki push payload."""
    streams: dict[str, list] = defaultdict(list)

    for entry in entries:
        labels = entry.get("labels", {})
        label_key = json.dumps(labels, sort_keys=True)
        ts_ns = str(int(entry.get("timestamp", time.time()) * 1e9))
        streams[label_key].append([ts_ns, entry.get("log_line", entry.get("message", ""))])

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
    secret = request.headers.get("X-Railway-Secret", "")
    if ENVIRONMENT == "production" and secret != LOG_RELAY_SECRET:
        return web.Response(status=401, text="Unauthorized")

    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

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
            "log_line": json.dumps({"msg": message}, separators=(",", ":")),
            "timestamp": time.time(),
        })

    if len(_buffer) >= MAX_BATCH_SIZE:
        await _flush_buffer()

    return web.Response(status=204)


async def handle_direct_push(request: web.Request) -> web.Response:
    """Handle structured log pushes from services.

    Phase 2 format:
    {
      "service": "automatos-backend",
      "level": "error",
      "message": "Something failed",
      "timestamp": 1741500000.123,
      "context": {"request_id": "...", "workspace_id": "...", ...},
      "error": {"type": "ValueError", "fingerprint": "abc123", ...},
      "metrics": {"duration_ms": 1523}
    }

    Also supports Phase 1 format (backwards compatible):
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

        # Build Loki labels — only bounded fields
        labels = {
            "job": f"automatos-{service}",
            "service": service,
            "level": level,
            "environment": ENVIRONMENT,
            "source": "direct-push",
        }

        # Phase 2: structured context with label promotion
        context = entry.get("context", {})
        extra = entry.get("extra", {})

        # Merge extra into context for backwards compat
        if extra and not context:
            context = extra

        # Promote bounded fields to labels
        module = context.get("module", extra.get("module", ""))
        if module:
            truncated = _truncate_module(module)
            if _should_promote_label("module", truncated):
                labels["module"] = truncated

        method = context.get("method", "")
        if method and _should_promote_label("method", method):
            labels["method"] = method

        # Error type as label (bounded — exception class names)
        error = entry.get("error", {})
        error_type = error.get("type", "")
        if error_type and _should_promote_label("error_type", error_type):
            labels["error_type"] = error_type

        # Build structured log line
        if context or error or entry.get("metrics"):
            # Phase 2: structured JSON log line
            log_line = _build_structured_log_line(entry)
        elif extra:
            # Phase 1 compat: message | extra JSON
            log_line = f"{message} | {json.dumps(extra)}"
        else:
            log_line = json.dumps({"msg": message}, separators=(",", ":"))

        _buffer.append({
            "labels": labels,
            "log_line": log_line,
            "timestamp": entry.get("timestamp", time.time()),
        })

    if len(_buffer) >= MAX_BATCH_SIZE:
        await _flush_buffer()

    return web.Response(status=204)


async def handle_health(request: web.Request) -> web.Response:
    return web.json_response({
        "status": "healthy",
        "service": "log-relay",
        "version": "2.0.0",
        "buffer_size": len(_buffer),
        "loki_url": LOKI_PUSH_URL,
        "label_cardinality": {k: len(v) for k, v in _label_cardinality.items()},
    })


async def handle_root(request: web.Request) -> web.Response:
    """Root handler — service info."""
    return web.json_response({
        "service": "automatos-log-relay",
        "version": "2.0.0",
        "phase": "Phase 2 — Structured Observability",
        "endpoints": {
            "drain": "POST /drain — Railway log drain webhooks",
            "push": "POST /push — Structured log push from services",
            "health": "GET /health — Health check with buffer stats",
        },
        "labels_promoted": sorted(LABEL_FIELDS),
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
    print(f"Log relay v2.0 starting on port {port}")
    print(f"Loki push URL: {LOKI_PUSH_URL}")
    print(f"Labels promoted: {sorted(LABEL_FIELDS)}")
    web.run_app(app, host="0.0.0.0", port=port)

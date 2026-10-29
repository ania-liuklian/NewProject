"""Authenticated Lambda URL handler for Cloudflare Workers AI agenda parsing."""

import asyncio
import base64
import json
import logging
import time
from datetime import date

from app.ai.agenda import PROMPT_VERSION, AgendaParseError, parse_agenda
from app.auth import TokenVerifier
from app.config import settings

log = logging.getLogger()
log.setLevel(logging.INFO)
verifier = TokenVerifier(settings.cognito_user_pool_id, settings.cognito_client_id)
MODEL_PRICES_PER_MILLION = {
    "@cf/meta/llama-3.3-70b-instruct-fp8-fast": (0.293, 2.253),
}


def response(status: int, body: dict) -> dict:
    return {"statusCode": status, "headers": {"content-type": "application/json"},
            "body": json.dumps(body, ensure_ascii=False)}


def handler(event, context):
    headers = {key.lower(): value for key, value in event.get("headers", {}).items()}
    authorization = headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        return response(401, {"error": "Sign in to parse an agenda."})
    try:
        claims = asyncio.run(verifier.verify(authorization[7:].strip()))
    except Exception:
        return response(401, {"error": "Your session is invalid or expired. Sign in again."})

    try:
        raw = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            raw = base64.b64decode(raw).decode()
        body = json.loads(raw)
        if not isinstance(body, dict):
            raise ValueError
        text = body.get("text")
        if not isinstance(text, str) or not text.strip():
            return response(400, {"error": "Paste agenda text first."})
        if len(text) > 10_000:
            return response(413, {"error": "Text must be 10,000 characters or fewer."})
        today = date.fromisoformat(body["today"])
        timezone = body["tz"]
        if not isinstance(timezone, str) or not timezone or len(timezone) > 100:
            raise ValueError
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        return response(400, {"error": "Send text, today's date, and your time zone."})

    started = time.monotonic()
    try:
        agenda, usage = parse_agenda(text, today, timezone)
    except AgendaParseError as error:
        message = str(error)
        throttled = any(token in message.lower() for token in ("429", "throttl", "http 5"))
        status = 503 if throttled else 422
        log.warning(json.dumps({"event": "agenda_parse_failed", "user": claims["sub"],
                                "provider": "cloudflare-workers-ai", "model": settings.parser_model,
                                "prompt_version": PROMPT_VERSION, "error": message[:300]}))
        return response(status, {"error": "Cloudflare Workers AI is busy or its free quota is exhausted; try again later." if status == 503 else message})

    prices = MODEL_PRICES_PER_MILLION.get(settings.parser_model)
    cost = None if prices is None or usage["input_tokens"] is None or usage["output_tokens"] is None else round(
        usage["input_tokens"] * prices[0] / 1_000_000
        + usage["output_tokens"] * prices[1] / 1_000_000,
        8,
    )

    log.info(json.dumps({
        "event": "agenda_parsed", "user": claims["sub"], "provider": "cloudflare-workers-ai",
        "model": settings.parser_model, "prompt_version": PROMPT_VERSION, **usage,
        "latency_ms": int((time.monotonic() - started) * 1000), "cost_usd": cost,
        "cost_basis": "estimated_on_demand_model_token_rates",
    }))
    return response(200, {"agenda": agenda.model_dump(mode="json"),
                          "model": settings.parser_model, "prompt_version": PROMPT_VERSION})

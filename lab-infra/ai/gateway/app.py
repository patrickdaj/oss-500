"""OSS-500 AI gateway (ai-access, ai-prompt, ai-guardrails, ai-governance, ai-observability).

The single, enforced hop in front of Ollama. Every request:
  1. must carry a bearer token           -> 401 (ai-access authn)
  2. is checked against the OPA policy    -> 403 governance / 429 quota (ai-governance)
  3. runs NeMo Guardrails input+output rails (ai-prompt / ai-guardrails)
  4. is traced to the OTel collector, emitting guardrail.blocked on a rail block

OpenAI-compatible (/v1/chat/completions, /v1/models) so Open WebUI can route
through it (OPENAI_API_BASE_URL) — making the gateway the ONLY path to Ollama.
Guardrails call Ollama themselves via guardrails/config.yml (engine: ollama).
"""
import os
import time
import uuid
from collections import defaultdict

import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse

# --- OpenTelemetry (ai-observability): GenAI spans, incl. guardrail.blocked ---
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

OTEL_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.oss500-apps:4317")
OPA_URL = os.environ.get("OPA_URL", "http://localhost:8181/v1/data/ai/gateway")
GUARDRAILS_CONFIG = os.environ.get("GUARDRAILS_CONFIG", "/config/guardrails")
SANCTIONED_MODELS = os.environ.get("SANCTIONED_MODELS", "llama3.2:1b,qwen2.5:0.5b").split(",")

_provider = TracerProvider(resource=Resource.create({"service.name": "ai-gateway"}))
_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)))
trace.set_tracer_provider(_provider)
tracer = trace.get_tracer("ai-gateway")

# --- NeMo Guardrails (ai-prompt / ai-guardrails) -----------------------------
# Loaded lazily so the process starts even while the model is still pulling.
_rails = None


def rails():
    global _rails
    if _rails is None:
        from nemoguardrails import LLMRails, RailsConfig
        _rails = LLMRails(RailsConfig.from_path(GUARDRAILS_CONFIG))
    return _rails


app = FastAPI(title="oss500-ai-gateway")

# --- ai-access: per-identity token-bucket rate limit -> 429 ------------------
_BUCKET_CAPACITY = int(os.environ.get("RATE_LIMIT_BURST", "10"))
_REFILL_PER_SEC = float(os.environ.get("RATE_LIMIT_RPS", "1"))
_buckets: dict[str, list[float]] = defaultdict(lambda: [float(_BUCKET_CAPACITY), time.monotonic()])


def _rate_ok(identity: str) -> bool:
    tokens, last = _buckets[identity]
    now = time.monotonic()
    tokens = min(_BUCKET_CAPACITY, tokens + (now - last) * _REFILL_PER_SEC)
    if tokens < 1:
        _buckets[identity] = [tokens, now]
        return False
    _buckets[identity] = [tokens - 1, now]
    return True


def _identity(authorization: str | None) -> dict:
    # ai-access: a bearer token is required. For the lab the token value IS the
    # username (a real deploy validates a Keycloak JWT and reads name/groups).
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="empty bearer token")
    groups = ["ml"] if token.startswith("ml-") else ["users"]
    return {"authenticated": True, "name": token, "groups": groups, "tokens_used_today": 0}


async def _opa_allows(user: dict, model: str) -> tuple[bool, str]:
    payload = {"input": {"user": user, "model": model}}
    async with httpx.AsyncClient(timeout=5) as c:
        r = await c.post(OPA_URL, json=payload)
        result = r.json().get("result", {})
    if result.get("allow") is True:
        return True, ""
    reasons = result.get("deny") or ["denied by policy"]
    return False, "; ".join(reasons)


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/v1/models")
def models(authorization: str | None = Header(default=None)):
    _identity(authorization)  # 401 if unauthenticated
    return {"object": "list", "data": [{"id": m, "object": "model"} for m in SANCTIONED_MODELS]}


@app.post("/v1/chat")            # lab-facing alias (labs/d3-ai-security, d5-ai-redteam)
@app.post("/v1/chat/completions")  # OpenAI-compatible (Open WebUI routes here)
async def chat(request: Request, authorization: str | None = Header(default=None)):
    body = await request.json()
    model = body.get("model", SANCTIONED_MODELS[0])
    messages = body.get("messages", [])
    with tracer.start_as_current_span("ai.chat") as span:
        user = _identity(authorization)                        # 401
        span.set_attribute("enduser.id", user["name"])
        span.set_attribute("gen_ai.request.model", model)

        if not _rate_ok(user["name"]):                          # 429
            raise HTTPException(status_code=429, detail="rate limit exceeded")

        ok, reason = await _opa_allows(user, model)             # 403 governance/quota
        if not ok:
            span.set_attribute("gateway.policy.denied", True)
            span.set_attribute("gateway.policy.reason", reason)
            raise HTTPException(status_code=403, detail=reason)

        # ai-prompt / ai-guardrails: input+output rails around the model.
        result = await rails().generate_async(messages=messages)
        content = result["content"] if isinstance(result, dict) else str(result)
        blocked = "i'm sorry" in content.lower() or "can't" in content.lower() or "cannot" in content.lower()
        span.set_attribute("guardrail.blocked", bool(blocked))

        return JSONResponse(
            {
                "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
                "object": "chat.completion",
                "model": model,
                "choices": [{"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": "stop"}],
            }
        )

#!/usr/bin/env python3
"""
Agent Tracing — Zero-dependency OTLP tracing hook (OTel GenAI semconv).

Emits standard OpenTelemetry (OTLP JSON) traces following the GenAI semantic
conventions (https://opentelemetry.io/docs/specs/semconv/gen-ai/) to any
configured backend (Langfuse, Jaeger, Honeycomb, Grafana Tempo, Datadog, etc.).

Shared by both VS Code Copilot Chat and Claude Code. Detects the calling
agent at runtime via stdin format:
  - VS Code: stdin contains {"hookEventName": ..., "transcript_path": ..., "sessionId": ...}
  - Claude:  stdin contains {"hook_event_name": "Stop", "session_id": ..., "transcript_path": ...}

Dependencies: Python 3.8+ stdlib only — no pip packages required.
"""

import base64, json, os, signal, sys, time, uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.error import URLError
from urllib.request import Request, urlopen

STDIN_TIMEOUT_SEC = 30
CONFIG_PATH = Path.home() / ".claude" / "hooks" / ".langfuse_config.json"

def load_config() -> dict:
    if CONFIG_PATH.exists():
        try: return json.loads(CONFIG_PATH.read_text())
        except (json.JSONDecodeError, IOError): pass
    return {}

_config = load_config()
LOG_DIR = _config.get("log_dir", "")
DEBUG = os.environ.get("CC_LANGFUSE_DEBUG", "").lower() == "true"

OTEL_SCOPE_NAME = "agent-tracing-hook"
OTEL_SCOPE_VERSION = "0.4.0"
OTEL_SERVICE_NAME = "agent-tracing"
EXPORT_TIMEOUT_SEC = 10

AGENT_META = {
    "github-copilot-chat": {"provider": "openai", "agent_name": "GitHub Copilot", "default_model": "copilot-agent", "environment": "github-copilot-chat"},
    "claude": {"provider": "anthropic", "agent_name": "Claude Code", "default_model": "claude-sonnet-4-20250514", "environment": "claude"},
}

# ---------------------------------------------------------------------------
# Exporters
# ---------------------------------------------------------------------------
def build_exporters(config: dict) -> List[dict]:
    if config.get("exporters"): return config["exporters"]
    pk = os.environ.get("LANGFUSE_PUBLIC_KEY", "") or config.get("public_key", "")
    sk = os.environ.get("LANGFUSE_SECRET_KEY", "") or config.get("secret_key", "")
    host = os.environ.get("LANGFUSE_HOST", "") or config.get("host", "http://localhost:3000")
    if not pk or not sk: return []
    auth = base64.b64encode(f"{pk}:{sk}".encode()).decode()
    return [{"name": "langfuse", "endpoint": f"{host.rstrip('/')}/api/public/otel/v1/traces", "headers": {"Authorization": f"Basic {auth}"}}]

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
def _log_path() -> Path:
    return (Path(LOG_DIR) if LOG_DIR else Path.home() / ".claude" / "state") / "hook.log"

def _write_line(line: str) -> None:
    try:
        p = _log_path(); p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, "a") as f: f.write(line)
    except OSError: pass

def log(level: str, message: str, agent: str = "unknown", sid: str = "") -> None:
    now = datetime.now()
    ts = now.strftime("%Y-%m-%d %H:%M:%S") + f".{now.microsecond // 1000:03d}"
    tag = f"{agent}/{sid}" if sid else agent
    line = f"{ts} [{level}] [{tag}] {message}\n"
    _write_line(line)
    if DEBUG: sys.stderr.write(line); sys.stderr.flush()

def debug(msg: str, agent: str = "unknown", sid: str = "") -> None:
    if DEBUG: log("DEBUG", msg, agent, sid)

# ---------------------------------------------------------------------------
# OTLP primitives
# ---------------------------------------------------------------------------
def gen_trace_id() -> str: return uuid.uuid4().hex
def gen_span_id() -> str: return uuid.uuid4().hex[:16]
def now_ns() -> str: return str(int(time.time() * 1e9))

def ts_to_ns(v: Any) -> str:
    if not v: return now_ns()
    if isinstance(v, (int, float)): return str(int(v * 1e9))
    if isinstance(v, str):
        try:
            dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
            return str(int(dt.timestamp() * 1e9))
        except ValueError: pass
    return now_ns()

def attr(key: str, value: Any) -> Optional[dict]:
    if value is None: return None
    if isinstance(value, bool): return {"key": key, "value": {"boolValue": value}}
    if isinstance(value, int): return {"key": key, "value": {"intValue": str(value)}}
    if isinstance(value, float): return {"key": key, "value": {"doubleValue": value}}
    if isinstance(value, (dict, list)): return {"key": key, "value": {"stringValue": json.dumps(value)}}
    s = str(value)
    return {"key": key, "value": {"stringValue": s}} if s else None

def make_span(trace_id: str, span_id: str, name: str, start_ns: str, end_ns: str,
              attributes: Dict[str, Any], parent_span_id: str = "", kind: int = 1, status_code: int = 1) -> dict:
    attrs = [a for a in (attr(k, v) for k, v in attributes.items()) if a is not None]
    span: Dict[str, Any] = {"traceId": trace_id, "spanId": span_id, "name": name, "kind": kind,
                             "startTimeUnixNano": start_ns, "endTimeUnixNano": end_ns,
                             "attributes": attrs, "status": {"code": status_code}}
    if parent_span_id: span["parentSpanId"] = parent_span_id
    return span

def make_resource_spans(spans: List[dict], agent: str) -> dict:
    meta = AGENT_META.get(agent, {})
    res_attrs = [a for a in [attr("service.name", OTEL_SERVICE_NAME), attr("deployment.environment", meta.get("environment", "default"))] if a is not None]
    return {"resource": {"attributes": res_attrs}, "scopeSpans": [{"scope": {"name": OTEL_SCOPE_NAME, "version": OTEL_SCOPE_VERSION}, "spans": spans}]}

def export_otlp(payload: dict, exporters: List[dict], agent: str = "unknown", sid: str = "") -> int:
    body = json.dumps(payload).encode("utf-8")
    ok = 0
    for exp in exporters:
        name, endpoint = exp.get("name", "?"), exp.get("endpoint", "")
        if not endpoint: continue
        headers = {"Content-Type": "application/json"}; headers.update(exp.get("headers", {}))
        try:
            req = Request(endpoint, data=body, headers=headers, method="POST")
            with urlopen(req, timeout=EXPORT_TIMEOUT_SEC) as resp:
                debug(f"Exported to {name}: HTTP {resp.status}", agent, sid); ok += 1
        except (URLError, Exception) as e:
            log("WARN", f"Export to {name} failed: {e}", agent, sid)
    return ok

# ---------------------------------------------------------------------------
# OTel GenAI message schema helpers
# ---------------------------------------------------------------------------
def fmt_input(role: str, text: str) -> dict:
    return {"role": role, "content": text}

def fmt_output(text: str, finish_reason: str = "stop") -> dict:
    return {"role": "assistant", "content": text}

def fmt_tool_call(tool_name: str, tc_id: str, args: Any) -> dict:
    return {"role": "assistant", "content": None, "tool_calls": [{"id": tc_id, "type": "function", "function": {"name": tool_name, "arguments": json.dumps(args) if isinstance(args, dict) else str(args)}}]}

def fmt_tool_result(tc_id: str, result: Any) -> dict:
    c = result if isinstance(result, str) else json.dumps(result) if result else ""
    return {"role": "tool", "tool_call_id": tc_id, "content": c[:2000]}

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
def trace_name(user_text: str, turn_num: int, max_len: int = 80) -> str:
    for raw_line in user_text.split("\n"):
        line = raw_line.strip().lstrip(">#- ").strip()
        if line: return (line[:max_len].rstrip() + "\u2026") if len(line) > max_len else line
    return f"Turn {turn_num}"

def output_and_exit(data: dict | None = None, code: int = 0) -> None:
    print(json.dumps(data or {}), flush=True); sys.exit(code)

# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------
def _state_path(agent: str) -> Path:
    return Path.home() / ".claude" / "state" / f"agent_tracing.{agent}.state.json"

def load_state(agent: str) -> dict:
    p = _state_path(agent)
    if not p.exists(): return {}
    try: return json.loads(p.read_text())
    except (json.JSONDecodeError, IOError): return {}

def save_state(agent: str, state: dict) -> None:
    p = _state_path(agent); p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(state, indent=2))

# ---------------------------------------------------------------------------
# Stdin
# ---------------------------------------------------------------------------
def resolve_uri(value: Any) -> str:
    if isinstance(value, str): return value
    if isinstance(value, dict): return value.get("fsPath") or value.get("path") or ""
    return ""

def read_stdin() -> dict:
    try:
        if hasattr(signal, "SIGALRM"):
            old = signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError()))
            signal.alarm(STDIN_TIMEOUT_SEC)
        raw = sys.stdin.read()
        if hasattr(signal, "SIGALRM"): signal.alarm(0); signal.signal(signal.SIGALRM, old)
        if not raw.strip(): return {}
        return json.loads(raw)
    except (json.JSONDecodeError, IOError, TimeoutError): return {}

def detect_agent(hook_input: dict) -> str:
    if hook_input.get("hookEventName"): return "github-copilot-chat"
    if hook_input.get("hook_event_name"): return "claude"
    return "claude"

# ===========================================================================
# VS Code Copilot Chat
# ===========================================================================
def parse_vscode_events(lines: list[str]) -> list[dict]:
    events = []
    for line in lines:
        line = line.strip()
        if not line: continue
        try: events.append(json.loads(line))
        except json.JSONDecodeError: continue
    return events

def extract_vscode_session_info(events: list[dict]) -> dict:
    for ev in events:
        if ev.get("type") == "session.start":
            d = ev.get("data", {})
            return {"session_id": d.get("sessionId", ""), "version": d.get("copilotVersion", ""),
                    "vscode_version": d.get("vscodeVersion", ""), "producer": d.get("producer", ""),
                    "start_time": d.get("startTime", "")}
    return {}

def group_vscode_turns(events: list[dict]) -> list[dict]:
    turns: list[dict] = []
    current: dict | None = None
    # Index tool start/complete events by toolCallId
    tool_starts: dict[str, dict] = {}
    tool_completes: dict[str, dict] = {}
    for ev in events:
        t = ev.get("type", "")
        if t == "tool.execution_start":
            tc_id = ev.get("data", {}).get("toolCallId", "")
            if tc_id: tool_starts[tc_id] = ev
        elif t == "tool.execution_complete":
            tc_id = ev.get("data", {}).get("toolCallId", "")
            if tc_id: tool_completes[tc_id] = ev

    for ev in events:
        t = ev.get("type", "")
        if t == "user.message":
            if current is not None: turns.append(current)
            d = ev.get("data", {})
            current = {"user_content": d.get("content", ""), "assistant_messages": [],
                       "tool_executions": [], "timestamp": ev.get("timestamp", "")}
        elif t == "assistant.message" and current is not None:
            current["assistant_messages"].append(ev)

    if current is not None: turns.append(current)

    for turn in turns:
        for am in turn["assistant_messages"]:
            for tr in am.get("data", {}).get("toolRequests", []):
                tc_id = tr.get("toolCallId", "")
                if tc_id:
                    start_ev = tool_starts.get(tc_id, {})
                    end_ev = tool_completes.get(tc_id, {})
                    turn["tool_executions"].append({
                        "tool_call_id": tc_id,
                        "name": tr.get("name", "unknown"),
                        "arguments": tr.get("arguments", "{}"),
                        "completed": tc_id in tool_completes,
                        "success": end_ev.get("data", {}).get("success", False) if end_ev else None,
                        "start_ts": start_ev.get("timestamp", ""),
                        "end_ts": end_ev.get("timestamp", ""),
                    })
    return turns

def get_vscode_assistant_text(turn: dict) -> str:
    for am in reversed(turn["assistant_messages"]):
        c = am.get("data", {}).get("content", "")
        if c: return c
    return ""

def get_vscode_reasoning(turn: dict) -> str:
    parts = []
    for am in turn["assistant_messages"]:
        r = am.get("data", {}).get("reasoningText", "")
        if r: parts.append(r)
    return "\n".join(parts)

def get_vscode_last_assistant_ts(turn: dict) -> str:
    for am in reversed(turn["assistant_messages"]):
        ts = am.get("timestamp", "")
        if ts: return ts
    return ""

def build_vscode_turn_spans(session_id: str, turn_num: int, turn: dict, session_info: dict, agent: str) -> List[dict]:
    meta = AGENT_META[agent]
    user_text = turn["user_content"]
    output_text = get_vscode_assistant_text(turn)
    reasoning = get_vscode_reasoning(turn)
    tool_execs = turn["tool_executions"]

    trace_id = gen_trace_id()
    root_id = gen_span_id()
    start_ns = ts_to_ns(turn.get("timestamp"))
    end_ns = ts_to_ns(get_vscode_last_assistant_ts(turn)) or now_ns()
    spans: List[dict] = []

    # Build rich input/output messages including tool calls
    input_msgs = [fmt_input("user", user_text)]
    output_msgs = [fmt_output(output_text)]

    # Root: invoke_agent
    root_attrs: Dict[str, Any] = {
        "gen_ai.operation.name": "invoke_agent",
        "gen_ai.agent.name": meta["agent_name"],
        "gen_ai.provider.name": meta["provider"],
        "gen_ai.conversation.id": session_id,
        "gen_ai.request.model": meta["default_model"],
        "gen_ai.response.model": meta["default_model"],
        "gen_ai.input.messages": json.dumps(input_msgs),
        "gen_ai.output.messages": json.dumps(output_msgs),
    }
    for key in ("producer", "vscode_version", "version"):
        if session_info.get(key): root_attrs[key] = session_info[key]
    spans.append(make_span(trace_id, root_id, f"invoke_agent {meta['agent_name']}", start_ns, end_ns, root_attrs))

    # Chat span
    chat_id = gen_span_id()
    chat_attrs: Dict[str, Any] = {
        "gen_ai.operation.name": "chat", "gen_ai.provider.name": meta["provider"],
        "gen_ai.request.model": meta["default_model"], "gen_ai.response.model": meta["default_model"],
        "gen_ai.input.messages": json.dumps(input_msgs), "gen_ai.output.messages": json.dumps(output_msgs),
    }
    if reasoning: chat_attrs["gen_ai.reasoning"] = reasoning[:2000]
    spans.append(make_span(trace_id, chat_id, f"chat {meta['default_model']}", start_ns, end_ns, chat_attrs, parent_span_id=root_id, kind=3))

    # Tool/subagent spans
    for te in tool_execs:
        try: tool_input = json.loads(te["arguments"]) if isinstance(te["arguments"], str) else te["arguments"]
        except (json.JSONDecodeError, TypeError): tool_input = {"raw": te["arguments"]}

        tool_name = te["name"]
        tc_id = te.get("tool_call_id", "")
        t_start = ts_to_ns(te.get("start_ts")) if te.get("start_ts") else start_ns
        t_end = ts_to_ns(te.get("end_ts")) if te.get("end_ts") else end_ns

        tool_output: Dict[str, Any] = {"completed": te.get("completed", False)}
        if te.get("success") is not None: tool_output["success"] = te["success"]

        t_id = gen_span_id()

        if tool_name == "runSubagent":
            # Subagent → invoke_agent span
            desc = tool_input.get("description", "subagent")
            prompt = tool_input.get("prompt", "")
            spans.append(make_span(trace_id, t_id, f"invoke_agent {desc}", t_start, t_end, {
                "gen_ai.operation.name": "invoke_agent",
                "gen_ai.agent.name": desc,
                "gen_ai.provider.name": meta["provider"],
                "gen_ai.input.messages": json.dumps([fmt_input("user", prompt)]),
                "gen_ai.output.messages": json.dumps([fmt_output(json.dumps(tool_output))]),
                "gen_ai.tool.call.id": tc_id,
            }, parent_span_id=root_id))
        else:
            # Regular tool → execute_tool span
            spans.append(make_span(trace_id, t_id, f"execute_tool {tool_name}", t_start, t_end, {
                "gen_ai.operation.name": "execute_tool",
                "gen_ai.tool.name": tool_name, "gen_ai.tool.call.id": tc_id,
                "gen_ai.tool.call.arguments": json.dumps(tool_input),
                "gen_ai.tool.call.result": json.dumps(tool_output),
            }, parent_span_id=root_id))

    return spans

def process_vscode(exporters: List[dict], hook_input: dict) -> int:
    agent = "github-copilot-chat"
    session_id = hook_input.get("sessionId", "")
    transcript_path = resolve_uri(hook_input.get("transcript_path", "")) if "transcript_path" in hook_input else ""
    if not transcript_path: debug("No transcript_path", agent, session_id); return 0
    tf = Path(transcript_path)
    if not tf.exists(): debug(f"Transcript not found: {transcript_path}", agent, session_id); return 0
    if not session_id: session_id = tf.stem

    state = load_state(agent)
    ss = state.get(session_id, {})
    last_line, turn_count = ss.get("last_line", 0), ss.get("turn_count", 0)
    lines = tf.read_text().strip().split("\n")
    total = len(lines)
    if last_line >= total: return 0

    all_events = parse_vscode_events(lines)
    if not all_events: return 0
    si = extract_vscode_session_info(all_events)
    all_turns = group_vscode_turns(all_events)
    new_turns = all_turns[turn_count:]
    if not new_turns:
        state[session_id] = {"last_line": total, "turn_count": len(all_turns), "updated": datetime.now(timezone.utc).isoformat()}
        save_state(agent, state); return 0

    all_spans: List[dict] = []
    for idx, turn in enumerate(new_turns):
        all_spans.extend(build_vscode_turn_spans(session_id, turn_count + idx + 1, turn, si, agent))
    if all_spans:
        export_otlp({"resourceSpans": [make_resource_spans(all_spans, agent)]}, exporters, agent, session_id)

    created = len(new_turns)
    state[session_id] = {"last_line": total, "turn_count": turn_count + created, "updated": datetime.now(timezone.utc).isoformat()}
    save_state(agent, state); return created

# ===========================================================================
# Claude Code
# ===========================================================================
def get_content(msg: dict) -> Any:
    if isinstance(msg, dict):
        if "message" in msg: return msg["message"].get("content")
        return msg.get("content")
    return None

def get_tool_calls(msg: dict) -> list:
    c = get_content(msg)
    return [i for i in c if isinstance(i, dict) and i.get("type") == "tool_use"] if isinstance(c, list) else []

def get_tool_results(msg: dict) -> list:
    c = get_content(msg)
    return [i for i in c if isinstance(i, dict) and i.get("type") == "tool_result"] if isinstance(c, list) else []

def get_text_content(msg: dict) -> str:
    c = get_content(msg)
    if isinstance(c, str): return c
    if isinstance(c, list):
        parts = []
        for i in c:
            if isinstance(i, dict) and i.get("type") == "text": parts.append(i.get("text", ""))
            elif isinstance(i, str): parts.append(i)
        return "\n".join(parts)
    return ""

def get_thinking_content(msg: dict) -> str:
    c = get_content(msg)
    if isinstance(c, list):
        parts = []
        for i in c:
            if isinstance(i, dict) and i.get("type") == "thinking":
                parts.append(i.get("thinking", ""))
        return "\n".join(parts)
    return ""

def get_usage(msg: dict) -> dict:
    """Extract token usage from a Claude assistant message."""
    m = msg.get("message", msg) if isinstance(msg, dict) else {}
    return m.get("usage", {})

def is_assistant(msg: dict) -> bool:
    role = msg.get("role") or (msg.get("message", {}) or {}).get("role")
    return role == "assistant"

def is_user(msg: dict) -> bool:
    role = msg.get("role") or (msg.get("message", {}) or {}).get("role")
    return role == "user"

def group_claude_turns(messages: list[dict]) -> list[dict]:
    turns: list[dict] = []
    current: dict | None = None
    for msg in messages:
        if is_user(msg):
            tool_results = get_tool_results(msg)
            if tool_results and current is not None:
                for tr in tool_results:
                    tid = tr.get("tool_use_id", "")
                    if tid:
                        current["tool_results"][tid] = tr
                        # Attach rich toolUseResult metadata
                        tur = msg.get("toolUseResult", {})
                        if isinstance(tur, dict) and tur.get("agentId"):
                            current["subagent_results"][tid] = tur
                        current["tool_result_timestamps"][tid] = msg.get("timestamp", "")
            else:
                if current is not None: turns.append(current)
                current = {"user_text": get_text_content(msg), "assistant_messages": [],
                           "tool_calls": [], "tool_results": {}, "subagent_results": {},
                           "tool_call_timestamps": {}, "tool_result_timestamps": {},
                           "timestamp": msg.get("timestamp", "")}
        elif is_assistant(msg) and current is not None:
            current["assistant_messages"].append(msg)
            for tc in get_tool_calls(msg):
                current["tool_calls"].append(tc)
                current["tool_call_timestamps"][tc.get("id", "")] = msg.get("timestamp", "")
        elif current is not None:
            for tr in get_tool_results(msg):
                tid = tr.get("tool_use_id", "")
                if tid:
                    current["tool_results"][tid] = tr
                    current["tool_result_timestamps"][tid] = msg.get("timestamp", "")
    if current is not None: turns.append(current)
    return turns


def build_claude_subagent_spans(trace_id: str, parent_id: str, agent_id: str,
                                transcript_path: str, start_ns: str, end_ns: str,
                                agent: str) -> List[dict]:
    """Parse a Claude subagent transcript and return child spans."""
    # Derive subagent transcript path: <session_dir>/subagents/agent-<id>.jsonl
    tp = Path(transcript_path)
    subagent_file = tp.parent / tp.stem / "subagents" / f"agent-{agent_id}.jsonl"
    if not subagent_file.exists():
        return []

    spans: List[dict] = []
    meta = AGENT_META[agent]
    messages = []
    for line in subagent_file.read_text().strip().split("\n"):
        line = line.strip()
        if not line: continue
        try: messages.append(json.loads(line))
        except json.JSONDecodeError: continue

    # Extract model from first assistant message
    model = meta["default_model"]
    for msg in messages:
        if msg.get("type") == "assistant":
            m = msg.get("message", {})
            if m.get("model"): model = m["model"]; break

    # Chat span for the subagent's LLM call
    chat_id = gen_span_id()
    # Collect subagent tool calls
    sub_tools: List[dict] = []
    for msg in messages:
        if msg.get("type") == "assistant":
            for tc in get_tool_calls(msg):
                sub_tools.append({"tc": tc, "ts": msg.get("timestamp", "")})

    # Collect subagent tool results
    sub_results: Dict[str, dict] = {}
    sub_result_ts: Dict[str, str] = {}
    for msg in messages:
        if msg.get("type") == "user":
            for tr in get_tool_results(msg):
                tid = tr.get("tool_use_id", "")
                if tid:
                    sub_results[tid] = tr
                    sub_result_ts[tid] = msg.get("timestamp", "")

    # Get subagent's final text output
    sub_output = ""
    for msg in reversed(messages):
        if msg.get("type") == "assistant":
            t = get_text_content(msg)
            if t: sub_output = t; break

    # Chat span
    spans.append(make_span(trace_id, chat_id, f"chat {model}", start_ns, end_ns, {
        "gen_ai.operation.name": "chat", "gen_ai.provider.name": meta["provider"],
        "gen_ai.request.model": model, "gen_ai.response.model": model,
        "gen_ai.output.messages": json.dumps([fmt_output(sub_output)]),
    }, parent_span_id=parent_id, kind=3))

    # Tool spans within subagent
    for st in sub_tools:
        tc = st["tc"]
        tc_name, tc_id = tc.get("name", "unknown"), tc.get("id", "")
        tc_input = tc.get("input", {})
        t_start = ts_to_ns(st["ts"]) if st["ts"] else start_ns
        t_end = ts_to_ns(sub_result_ts.get(tc_id, "")) if sub_result_ts.get(tc_id) else end_ns

        result = sub_results.get(tc_id, {})
        result_content = result.get("content", "")
        if isinstance(result_content, list):
            result_content = " ".join(i.get("text", "") if isinstance(i, dict) else str(i) for i in result_content)

        t_attrs: Dict[str, Any] = {
            "gen_ai.operation.name": "execute_tool", "gen_ai.tool.name": tc_name,
            "gen_ai.tool.call.id": tc_id, "gen_ai.tool.call.arguments": json.dumps(tc_input),
        }
        if result_content:
            t_attrs["gen_ai.tool.call.result"] = result_content[:2000]

        spans.append(make_span(trace_id, gen_span_id(), f"execute_tool {tc_name}",
                               t_start, t_end, t_attrs, parent_span_id=parent_id))

    return spans


def build_claude_turn_spans(session_id: str, turn_num: int, turn: dict, agent: str,
                            transcript_path: str = "", agent_name: str = "") -> List[dict]:
    meta = dict(AGENT_META[agent])
    if agent_name: meta["agent_name"] = agent_name
    user_text = turn["user_text"]
    assistant_texts = [get_text_content(m) for m in turn["assistant_messages"]]
    final_output = next((t for t in reversed(assistant_texts) if t), "")

    # Extract thinking
    thinking_parts = []
    for m in turn["assistant_messages"]:
        t = get_thinking_content(m)
        if t: thinking_parts.append(t)
    thinking = "\n".join(thinking_parts)

    # Extract model
    model = meta["default_model"]
    for m in turn["assistant_messages"]:
        am = m.get("message", m) if isinstance(m, dict) else {}
        if am.get("model"): model = am["model"]; break

    # Aggregate token usage across all assistant messages in turn
    total_in, total_out = 0, 0
    for m in turn["assistant_messages"]:
        u = get_usage(m)
        total_in += u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
        total_out += u.get("output_tokens", 0)

    # Timestamps from transcript
    start_ns = ts_to_ns(turn.get("timestamp"))
    # End = last assistant message timestamp
    last_ts = ""
    for m in reversed(turn["assistant_messages"]):
        ts = m.get("timestamp", "")
        if ts: last_ts = ts; break
    end_ns = ts_to_ns(last_ts) if last_ts else now_ns()

    trace_id = gen_trace_id()
    root_id = gen_span_id()
    spans: List[dict] = []

    # Build rich messages
    input_msgs = [fmt_input("user", user_text)]
    output_msgs = [fmt_output(final_output)]
    # Add tool calls and results to messages
    for tc in turn["tool_calls"]:
        input_msgs.append(fmt_tool_call(tc.get("name", ""), tc.get("id", ""), tc.get("input", {})))
        result = turn["tool_results"].get(tc.get("id", ""), {})
        rc = result.get("content", "")
        if isinstance(rc, list):
            rc = " ".join(i.get("text", "") if isinstance(i, dict) else str(i) for i in rc)
        if rc: input_msgs.append(fmt_tool_result(tc.get("id", ""), rc))

    # Root: invoke_agent — clean user prompt only for column display
    root_attrs: Dict[str, Any] = {
        "gen_ai.operation.name": "invoke_agent",
        "gen_ai.agent.name": meta["agent_name"], "gen_ai.provider.name": meta["provider"],
        "gen_ai.conversation.id": session_id,
        "gen_ai.request.model": model, "gen_ai.response.model": model,
        "gen_ai.input.messages": json.dumps([fmt_input("user", user_text)]),
        "gen_ai.output.messages": json.dumps(output_msgs),
    }
    if total_in: root_attrs["gen_ai.usage.input_tokens"] = total_in
    if total_out: root_attrs["gen_ai.usage.output_tokens"] = total_out
    spans.append(make_span(trace_id, root_id, f"invoke_agent {meta['agent_name']}", start_ns, end_ns, root_attrs))

    # Chat span — full messages including tool calls/results
    chat_id = gen_span_id()
    chat_attrs: Dict[str, Any] = {
        "gen_ai.operation.name": "chat", "gen_ai.provider.name": meta["provider"],
        "gen_ai.request.model": model, "gen_ai.response.model": model,
        "gen_ai.input.messages": json.dumps(input_msgs),
        "gen_ai.output.messages": json.dumps(output_msgs),
    }
    if thinking: chat_attrs["gen_ai.reasoning"] = thinking[:4000]
    if total_in: chat_attrs["gen_ai.usage.input_tokens"] = total_in
    if total_out: chat_attrs["gen_ai.usage.output_tokens"] = total_out
    spans.append(make_span(trace_id, chat_id, f"chat {model}", start_ns, end_ns, chat_attrs, parent_span_id=root_id, kind=3))

    # Tool/subagent spans
    for tc in turn["tool_calls"]:
        tc_name = tc.get("name", "unknown")
        tc_id_val = tc.get("id", "")
        tc_input = tc.get("input", {})
        t_start = ts_to_ns(turn["tool_call_timestamps"].get(tc_id_val, ""))
        t_end = ts_to_ns(turn["tool_result_timestamps"].get(tc_id_val, "")) if turn["tool_result_timestamps"].get(tc_id_val) else end_ns

        result = turn["tool_results"].get(tc_id_val, {})
        result_content = result.get("content", "")
        if isinstance(result_content, list):
            result_content = " ".join(i.get("text", "") if isinstance(i, dict) else str(i) for i in result_content)
        is_error = result.get("is_error", False)

        t_id = gen_span_id()

        if tc_name == "Task":
            # Subagent → invoke_agent
            desc = tc_input.get("description", "subagent")
            prompt = tc_input.get("prompt", "")
            sub_result = turn["subagent_results"].get(tc_id_val, {})
            agent_id = sub_result.get("agentId", "")

            sa_attrs: Dict[str, Any] = {
                "gen_ai.operation.name": "invoke_agent",
                "gen_ai.agent.name": desc,
                "gen_ai.provider.name": meta["provider"],
                "gen_ai.input.messages": json.dumps([fmt_input("user", prompt)]),
                "gen_ai.tool.call.id": tc_id_val,
            }
            if agent_id: sa_attrs["gen_ai.agent.id"] = agent_id
            if result_content: sa_attrs["gen_ai.output.messages"] = json.dumps([fmt_output(result_content[:2000])])
            # Subagent token usage
            sub_tokens = sub_result.get("totalTokens", 0)
            sub_dur = sub_result.get("totalDurationMs", 0)
            sub_usage = sub_result.get("usage", {})
            if sub_usage:
                sa_in = sub_usage.get("input_tokens", 0) + sub_usage.get("cache_read_input_tokens", 0)
                sa_out = sub_usage.get("output_tokens", 0)
                if sa_in: sa_attrs["gen_ai.usage.input_tokens"] = sa_in
                if sa_out: sa_attrs["gen_ai.usage.output_tokens"] = sa_out

            spans.append(make_span(trace_id, t_id, f"invoke_agent {desc}", t_start, t_end,
                                   sa_attrs, parent_span_id=root_id))

            # Parse subagent transcript for child spans
            if agent_id and transcript_path:
                child_spans = build_claude_subagent_spans(trace_id, t_id, agent_id,
                                                          transcript_path, t_start, t_end, agent)
                spans.extend(child_spans)
        else:
            # Regular tool → execute_tool
            t_attrs: Dict[str, Any] = {
                "gen_ai.operation.name": "execute_tool", "gen_ai.tool.name": tc_name,
                "gen_ai.tool.call.id": tc_id_val, "gen_ai.tool.call.arguments": json.dumps(tc_input),
            }
            if result_content: t_attrs["gen_ai.tool.call.result"] = result_content[:2000]
            if is_error: t_attrs["error.type"] = "tool_error"
            spans.append(make_span(trace_id, t_id, f"execute_tool {tc_name}", t_start, t_end,
                                   t_attrs, parent_span_id=root_id, status_code=2 if is_error else 1))

    return spans


def process_claude(exporters: List[dict], hook_input: dict) -> int:
    agent = "claude"
    session_id = hook_input.get("session_id", "")
    transcript_path = hook_input.get("transcript_path", "")
    if not transcript_path: debug("No transcript_path", agent, session_id); return 0
    tf = Path(transcript_path)
    if not tf.exists(): debug(f"Not found: {transcript_path}", agent, session_id); return 0
    if not session_id: session_id = tf.stem

    state = load_state(agent)
    ss = state.get(session_id, {})
    last_line, turn_count = ss.get("last_line", 0), ss.get("turn_count", 0)
    lines = tf.read_text().strip().split("\n")
    total = len(lines)
    if last_line >= total: return 0

    messages = []
    for line in lines:
        line = line.strip()
        if not line: continue
        try: messages.append(json.loads(line))
        except json.JSONDecodeError: continue
    if not messages: return 0

    # Detect entrypoint for agent name (claude-vscode vs claude CLI)
    agent_name = ""
    for msg in messages[:10]:
        ep = msg.get("entrypoint", "")
        if ep == "claude-vscode": agent_name = "Claude VSCode"; break
        elif ep == "claude": agent_name = "Claude CLI"; break

    # OTEL hook is VSCode-only; CLI sessions use the langfuse-observability plugin
    if agent_name != "Claude VSCode":
        log("INFO", "Skipping non-VSCode session (CLI uses langfuse-observability plugin)", agent, session_id)
        output_and_exit(); return 0

    all_turns = group_claude_turns(messages)
    new_turns = all_turns[turn_count:]
    if not new_turns:
        state[session_id] = {"last_line": total, "turn_count": len(all_turns), "updated": datetime.now(timezone.utc).isoformat()}
        save_state(agent, state); return 0

    all_spans: List[dict] = []
    for idx, turn in enumerate(new_turns):
        all_spans.extend(build_claude_turn_spans(session_id, turn_count + idx + 1, turn, agent, transcript_path, agent_name))
    if all_spans:
        export_otlp({"resourceSpans": [make_resource_spans(all_spans, agent)]}, exporters, agent, session_id)

    created = len(new_turns)
    state[session_id] = {"last_line": total, "turn_count": turn_count + created, "updated": datetime.now(timezone.utc).isoformat()}
    save_state(agent, state); return created

# ===========================================================================
# Entry point
# ===========================================================================
def main() -> None:
    script_start = datetime.now()
    agent, session_id, exit_code = "unknown", "", 0
    try:
        hook_input = read_stdin()
        agent = detect_agent(hook_input)
        session_id = hook_input.get("sessionId") or hook_input.get("session_id", "")
        transcript = resolve_uri(hook_input.get("transcript_path", "")) if "transcript_path" in hook_input else ""

        exporters = build_exporters(_config)
        names = [e.get("name", "?") for e in exporters]
        log("INFO", f"Hook invoked: agent={agent} exporters={names}", agent, session_id)
        debug(f"stdin keys: {list(hook_input.keys())}", agent, session_id)
        if transcript: debug(f"transcript: {transcript}", agent, session_id)

        enabled = os.environ.get("AGENT_TRACING_ENABLED", "").lower() == "true" or os.environ.get("TRACE_TO_LANGFUSE", "").lower() == "true"
        if not enabled:
            log("INFO", "Tracing disabled — exiting", agent, session_id); output_and_exit()

        if not exporters:
            log("ERROR", "No exporters configured", agent, session_id); output_and_exit(code=1)

        turns = process_vscode(exporters, hook_input) if agent == "github-copilot-chat" else process_claude(exporters, hook_input)
        duration = (datetime.now() - script_start).total_seconds()
        log("INFO", f"Done: {turns} turn(s) in {duration:.1f}s → {names}", agent, session_id)
    except Exception as e:
        exit_code = 1
        try: log("ERROR", f"Unhandled: {e}", agent, session_id)
        except Exception: pass
    output_and_exit(code=exit_code)

if __name__ == "__main__":
    main()

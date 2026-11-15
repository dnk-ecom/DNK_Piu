#!/usr/bin/env python3
"""DNK_Piu Permission Hook for Antigravity (PreToolUse), Hermes, and Claude Code."""
import json
import os
import sys
import time
import uuid

PIU_ROOT = os.path.expanduser("~/.dnk_runtime/piu")
PENDING = os.path.join(PIU_ROOT, "pending")
RESPONSES = os.path.join(PIU_ROOT, "responses")
HEARTBEAT = os.path.join(PIU_ROOT, "app.heartbeat")
WAIT_SECONDS = float(os.environ.get("PIU_WAIT_SECONDS", "120"))
HEARTBEAT_MAX_AGE = 5.0
POLL_INTERVAL = 0.15

def is_piu_alive() -> bool:
    try:
        return time.time() - os.path.getmtime(HEARTBEAT) < HEARTBEAT_MAX_AGE
    except OSError:
        return False

def write_atomic_json(path: str, data: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)

def cleanup(*paths: str) -> None:
    for p in paths:
        try:
            os.remove(p)
        except OSError:
            pass

def main():
    # If DNK_Piu is not running, fall back to asking in terminal immediately
    if not is_piu_alive():
        print(json.dumps({"decision": "ask"}))
        return

    # Parse input payload from stdin or argument
    payload = {}
    if not sys.stdin.isatty():
        try:
            payload = json.load(sys.stdin)
        except Exception:
            payload = {}

    req_id = payload.get("id") or str(uuid.uuid4())
    session_id = payload.get("sessionId") or payload.get("session_id") or "default_session"
    tool_name = payload.get("toolName") or payload.get("tool_name") or "unknown_tool"
    tool_input = payload.get("toolInput") or payload.get("tool_input") or {}
    agent_type = payload.get("agentType") or payload.get("agent_type") or "antigravity"

    pending_data = {
        "id": req_id,
        "sessionId": session_id,
        "cwd": os.getcwd(),
        "toolName": tool_name,
        "toolInput": tool_input,
        "agentType": agent_type,
        "createdAt": time.time(),
        "hookPid": os.getpid()
    }

    os.makedirs(PENDING, exist_ok=True)
    os.makedirs(RESPONSES, exist_ok=True)

    pending_file = os.path.join(PENDING, f"{req_id}.json")
    response_file = os.path.join(RESPONSES, f"{req_id}.json")

    write_atomic_json(pending_file, pending_data)

    deadline = time.time() + WAIT_SECONDS
    decision_output = {"decision": "ask"}

    try:
        while time.time() < deadline:
            if not is_piu_alive():
                break
            if os.path.isfile(response_file):
                try:
                    with open(response_file, "r", encoding="utf-8") as f:
                        resp = json.load(f)
                    decision = resp.get("decision") or resp.get("behavior") or "allow"
                    decision_output = {"decision": decision}
                    if "message" in resp:
                        decision_output["reason"] = resp["message"]
                    break
                except Exception:
                    pass
            time.sleep(POLL_INTERVAL)
    finally:
        cleanup(pending_file, response_file)

    print(json.dumps(decision_output))

if __name__ == "__main__":
    main()

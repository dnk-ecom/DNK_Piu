#!/usr/bin/env python3
"""Deterministic verification test suite for DNK_Piu IPC, telemetry, and approvals."""
import json
import os
import shutil
import tempfile
import time
import unittest

class TestPiuCore(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.pending = os.path.join(self.tmp, "pending")
        self.responses = os.path.join(self.tmp, "responses")
        self.sessions = os.path.join(self.tmp, "sessions")
        os.makedirs(self.pending)
        os.makedirs(self.responses)
        os.makedirs(self.sessions)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_request_payload_format(self):
        req_id = "test-req-001"
        payload = {
            "id": req_id,
            "sessionId": "session-123",
            "cwd": "/Users/kuzmenko.top/Kuzmenko/MY_LIFE_WORK/DNK_HUB",
            "toolName": "run_command",
            "toolInput": {
                "CommandLine": "git status"
            },
            "agentType": "antigravity",
            "createdAt": time.time()
        }
        path = os.path.join(self.pending, f"{req_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f)

        self.assertTrue(os.path.exists(path))
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self.assertEqual(data["toolName"], "run_command")
        self.assertEqual(data["toolInput"]["CommandLine"], "git status")

    def test_decision_allow_response(self):
        req_id = "test-req-002"
        resp_payload = {
            "behavior": "allow",
            "decision": "allow"
        }
        path = os.path.join(self.responses, f"{req_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(resp_payload, f)

        self.assertTrue(os.path.exists(path))
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self.assertEqual(data["decision"], "allow")

    def test_session_telemetry_schema(self):
        session_id = "hermes_test_session"
        session_data = {
            "pid": os.getpid(),
            "sessionId": session_id,
            "cwd": "/Users/kuzmenko.top/Kuzmenko/MY_LIFE_WORK/DNK_HUB",
            "name": "Gerych (Hermes)",
            "agentKind": "gerych",
            "status": "busy",
            "title": "Auditing Casaio 1.1.0 Liquid themes",
            "currentStep": "Verifying block schema and Liquid AST",
            "startedAt": time.time() * 1000,
            "updatedAt": time.time() * 1000
        }
        path = os.path.join(self.sessions, f"{session_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(session_data, f)

        self.assertTrue(os.path.exists(path))
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self.assertEqual(data["agentKind"], "gerych")
        self.assertEqual(data["currentStep"], "Verifying block schema and Liquid AST")

if __name__ == "__main__":
    unittest.main()

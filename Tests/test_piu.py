#!/usr/bin/env python3
import json
import os
import shutil
import tempfile
import unittest

class TestPiuCore(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.pending = os.path.join(self.tmp, "pending")
        self.responses = os.path.join(self.tmp, "responses")
        os.makedirs(self.pending)
        os.makedirs(self.responses)

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
            "createdAt": 1731715000.0
        }
        path = os.path.join(self.pending, f"{req_id}.json")
        with open(path, "w") as f:
            json.dump(payload, f)

        self.assertTrue(os.path.exists(path))
        with open(path) as f:
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
        with open(path, "w") as f:
            json.dump(resp_payload, f)

        self.assertTrue(os.path.exists(path))
        with open(path) as f:
            data = json.load(f)
        self.assertEqual(data["decision"], "allow")

if __name__ == "__main__":
    unittest.main()

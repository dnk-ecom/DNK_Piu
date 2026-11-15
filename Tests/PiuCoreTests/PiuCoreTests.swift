import Foundation
@testable import PiuCore
import XCTest

final class PiuCoreTests: XCTestCase {
    func testPiuPaths() {
        let paths = PiuPaths()
        XCTAssertTrue(paths.root.path.contains(".dnk_runtime/piu"))
        XCTAssertTrue(paths.pending.path.contains("pending"))
        XCTAssertTrue(paths.responses.path.contains("responses"))
    }

    func testPendingRequestParsing() {
        let json: [String: Any] = [
            "id": "req-123",
            "sessionId": "session-456",
            "toolName": "run_command",
            "toolInput": [
                "CommandLine": "git status"
            ],
            "agentType": "antigravity"
        ]
        let req = PendingRequest(json: json)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.id, "req-123")
        XCTAssertEqual(req?.sessionId, "session-456")
        XCTAssertEqual(req?.summary, "git status")
    }

    func testBuddyDeterminism() {
        let b1 = BuddyTraits(seed: "session-abc")
        let b2 = BuddyTraits(seed: "session-abc")
        XCTAssertEqual(b1.name, b2.name)
        XCTAssertEqual(b1.shape, b2.shape)
        XCTAssertEqual(b1.color, b2.color)
    }

    func testDecisionsAllow() {
        let req = PendingRequest(id: "r1", sessionId: "s1", toolName: "run_command")
        let payload = Decisions.allow(req)
        XCTAssertEqual(payload["decision"] as? String, "allow")
        XCTAssertEqual(payload["behavior"] as? String, "allow")
    }

    func testDecisionsDeny() {
        let payload = Decisions.deny(note: "Unsafe script")
        XCTAssertEqual(payload["decision"] as? String, "deny")
        XCTAssertEqual(payload["behavior"] as? String, "deny")
        XCTAssertEqual(payload["message"] as? String, "Unsafe script")
    }
}

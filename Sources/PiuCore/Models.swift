import Foundation

/// System paths for DNK_Piu IPC and session discovery.
public struct PiuPaths {
    public let root: URL

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".dnk_runtime").appendingPathComponent("piu")) {
        self.root = root
    }

    public var sessions: URL { root.appendingPathComponent("sessions") }
    public var pending: URL { root.appendingPathComponent("pending") }
    public var responses: URL { root.appendingPathComponent("responses") }
    public var status: URL { root.appendingPathComponent("status") }
    public var heartbeat: URL { root.appendingPathComponent("app.heartbeat") }

    /// Fallback directory to monitor legacy Claude Code sessions if present
    public static var claudeHuddle: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").appendingPathComponent("huddle")
    }
}

public enum AgentKind: String, Codable {
    case antigravity = "antigravity"
    case gerych = "gerych"
    case denchik = "denchik"
    case claude = "claude"
    case unknown = "agent"

    public var displayName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .gerych: return "Gerych (Hermes)"
        case .denchik: return "Denchik (Builder)"
        case .claude: return "Claude Code"
        case .unknown: return "Agent"
        }
    }

    public var badgeColor: String {
        switch self {
        case .antigravity: return "#E879F9"
        case .gerych: return "#C084FC"
        case .denchik: return "#2DD4BF"
        case .claude: return "#D97757"
        case .unknown: return "#8AB4F8"
        }
    }
}

/// One live agent session.
public struct SessionInfo: Identifiable, Equatable {
    public var id: String { sessionId }
    public var pid: Int32
    public var sessionId: String
    public var cwd: String
    public var name: String
    public var rawStatus: String
    public var entrypoint: String
    public var agentKind: AgentKind
    public var startedAt: Date
    public var updatedAt: Date

    public init(pid: Int32, sessionId: String, cwd: String, name: String, rawStatus: String,
                entrypoint: String, agentKind: AgentKind = .unknown, startedAt: Date = Date(), updatedAt: Date = Date()) {
        self.pid = pid
        self.sessionId = sessionId
        self.cwd = cwd
        self.name = name
        self.rawStatus = rawStatus
        self.entrypoint = entrypoint
        self.agentKind = agentKind
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    public var project: String {
        let last = (cwd as NSString).lastPathComponent
        return last.isEmpty ? cwd : last
    }
}

public enum StepKind: Equatable { case prompt, text, tool }
public enum StepState: Equatable { case running, done, failed, info }

/// One step in an agent's execution timeline.
public struct Step: Identifiable, Equatable {
    public var id: String
    public var kind: StepKind
    public var state: StepState
    public var title: String
    public var detail: String
    public var time: Date?

    public init(id: String, kind: StepKind, state: StepState, title: String, detail: String = "", time: Date? = nil) {
        self.id = id
        self.kind = kind
        self.state = state
        self.title = title
        self.detail = detail
        self.time = time
    }
}

/// Token usage counts.
public struct Usage: Equatable {
    public var contextTokens = 0
    public var outputTokens = 0
    public var model = ""

    public init() {}
}

public struct TaskProgress: Equatable {
    public var done: Int
    public var total: Int
    public var current: String

    public init(done: Int, total: Int, current: String) {
        self.done = done
        self.total = total
        self.current = current
    }
}

public struct LimitWindow: Identifiable, Equatable {
    public var id: String { key }
    public var key: String
    public var label: String
    public var usedPercent: Double
    public var resetsAt: Date?

    public init(key: String, label: String, usedPercent: Double, resetsAt: Date?) {
        self.key = key
        self.label = label
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct SessionStatus: Equatable {
    public var updatedAt: Date
    public var model: String?
    public var contextPercent: Double?
    public var contextSize: Int?
    public var costUSD: Double?
    public var limits: [LimitWindow]

    public init(updatedAt: Date, model: String? = nil, contextPercent: Double? = nil, contextSize: Int? = nil,
                costUSD: Double? = nil, limits: [LimitWindow] = []) {
        self.updatedAt = updatedAt
        self.model = model
        self.contextPercent = contextPercent
        self.contextSize = contextSize
        self.costUSD = costUSD
        self.limits = limits
    }
}

public struct QuestionOption: Equatable {
    public var label: String
    public var description: String

    public init(label: String, description: String = "") {
        self.label = label
        self.description = description
    }
}

public struct Question: Identifiable, Equatable {
    public var id: String { question }
    public var question: String
    public var header: String
    public var options: [QuestionOption]
    public var multiSelect: Bool

    public init(question: String, header: String, options: [QuestionOption], multiSelect: Bool) {
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }
}

/// A permission prompt or question waiting for approval.
public struct PendingRequest: Identifiable {
    public var id: String
    public var sessionId: String
    public var cwd: String
    public var toolName: String
    public var toolInput: [String: Any]
    public var suggestions: [[String: Any]]
    public var agentType: String?
    public var createdAt: Date
    public var hookPid: Int32

    public init(id: String, sessionId: String, cwd: String = "", toolName: String, toolInput: [String: Any] = [:],
                suggestions: [[String: Any]] = [], agentType: String? = nil, createdAt: Date = Date(), hookPid: Int32 = 0) {
        self.id = id
        self.sessionId = sessionId
        self.cwd = cwd
        self.toolName = toolName
        self.toolInput = toolInput
        self.suggestions = suggestions
        self.agentType = agentType
        self.createdAt = createdAt
        self.hookPid = hookPid
    }

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let sessionId = json["sessionId"] as? String,
              let toolName = json["toolName"] as? String else { return nil }
        self.init(id: id, sessionId: sessionId, cwd: json["cwd"] as? String ?? "", toolName: toolName,
                  toolInput: json["toolInput"] as? [String: Any] ?? [:],
                  suggestions: json["suggestions"] as? [[String: Any]] ?? [],
                  agentType: json["agentType"] as? String,
                  createdAt: Date(timeIntervalSince1970: (json["createdAt"] as? NSNumber)?.doubleValue ?? 0),
                  hookPid: (json["hookPid"] as? NSNumber)?.int32Value ?? 0)
    }

    public var isQuestion: Bool { toolName == "AskUserQuestion" || toolName == "ask_question" }
    public var isPlan: Bool { toolName == "ExitPlanMode" }

    public var questions: [Question] {
        guard let raw = toolInput["questions"] as? [[String: Any]] else { return [] }
        return raw.compactMap { q in
            guard let text = q["question"] as? String else { return nil }
            let options = (q["options"] as? [[String: Any]] ?? []).compactMap { o -> QuestionOption? in
                guard let label = o["label"] as? String else { return nil }
                return QuestionOption(label: label, description: o["description"] as? String ?? "")
            }
            return Question(question: text, header: q["header"] as? String ?? "", options: options,
                            multiSelect: q["multiSelect"] as? Bool ?? false)
        }
    }

    /// Clean, readable summary of what the tool intends to do.
    public var summary: String {
        switch toolName {
        // Shell commands (Claude + Antigravity)
        case "Bash", "PowerShell", "Monitor", "run_command":
            return toolInput["command"] as? String ?? toolInput["CommandLine"] as? String ?? ""
        // Filesystem (Claude + Antigravity)
        case "Edit", "Write", "Read", "NotebookEdit", "edit_file", "write_file", "read_file":
            return toolInput["file_path"] as? String ?? toolInput["Path"] as? String ?? toolInput["notebook_path"] as? String ?? ""
        // Web queries
        case "WebFetch":
            return toolInput["url"] as? String ?? ""
        case "WebSearch", "search_web":
            return toolInput["query"] as? String ?? ""
        case "ExitPlanMode":
            return toolInput["plan"] as? String ?? ""
        default:
            guard !toolInput.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: toolInput, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else { return toolName }
            return text
        }
    }

    public var note: String {
        toolInput["description"] as? String ?? toolInput["toolSummary"] as? String ?? ""
    }
}

public func readJSON(_ url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

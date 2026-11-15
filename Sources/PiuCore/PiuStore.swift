import AppKit
import Foundation

/// Active agent session with real-time telemetry.
public struct AgentSession: Identifiable, Equatable {
    public var info: SessionInfo
    public var steps: [Step] = []
    public var usage = Usage()
    public var title: String?
    public var status: SessionStatus?
    public var tasks: TaskProgress?

    public var id: String { info.sessionId }
    public var buddy: BuddyTraits { BuddyTraits(seed: info.sessionId) }

    public var displayName: String {
        if let title, !title.isEmpty { return title }
        return info.name.isEmpty ? info.project : info.name
    }

    public var currentStep: String {
        guard let last = steps.last else { return "Ready" }
        if last.kind == .tool { return last.detail.isEmpty ? last.title : "\(last.title): \(last.detail)" }
        return last.title
    }

    public static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id && lhs.info == rhs.info && lhs.steps == rhs.steps
    }
}

public enum Activity: Int {
    case needsYou, working, idle

    public var label: String {
        switch self {
        case .needsYou: return "Needs approval"
        case .working: return "Working"
        case .idle: return "Idle"
        }
    }
}

public final class PiuStore: ObservableObject {
    @Published public var sessions: [AgentSession] = []
    @Published public var pending: [PendingRequest] = []
    @Published public var limits: [LimitWindow] = []
    @Published public var expanded = false
    @Published public var selected: String?
    @Published public var now = Date()

    @Published public var picks: [String: Set<String>] = [:]
    @Published public var customText: [String: String] = [:]
    @Published public var denyNote: [String: String] = [:]
    @Published public var armed = true
    @Published public var feedback: [String: String] = [:]
    @Published public var panelHeight: CGFloat = 300
    @Published public var muted = UserDefaults.standard.bool(forKey: "muted") {
        didSet { UserDefaults.standard.set(muted, forKey: "muted") }
    }

    public let dictation = AudioDictation.shared
    public let paths: PiuPaths
    private var timer: Timer?
    private var heartbeatTimer: DispatchSourceTimer?
    private let scanQueue = DispatchQueue(label: "piu.scan")
    private var answered: Set<String> = []

    public init(paths: PiuPaths = PiuPaths()) {
        self.paths = paths
    }

    public func start() {
        for folder in [paths.root, paths.sessions, paths.pending, paths.responses, paths.status] {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
        }

        // Heartbeat timer to signal hooks that DNK_Piu is active
        let beat = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        let file = paths.heartbeat
        beat.schedule(deadline: .now(), repeating: 1)
        beat.setEventHandler { try? Data().write(to: file) }
        beat.resume()
        heartbeatTimer = beat

        tick()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        timer?.invalidate()
        timer = nil
        try? FileManager.default.removeItem(at: paths.heartbeat)
    }

    public func requests(for sessionId: String) -> [PendingRequest] {
        pending.filter { $0.sessionId == sessionId }
    }

    public func activity(_ session: AgentSession) -> Activity {
        if !requests(for: session.id).isEmpty { return .needsYou }
        return session.info.rawStatus == "busy" ? .working : .idle
    }

    public var ordered: [AgentSession] {
        sessions.enumerated().sorted { a, b in
            let (x, y) = (activity(a.element).rawValue, activity(b.element).rawValue)
            return x == y ? a.offset < b.offset : x < y
        }.map(\.element)
    }

    public var needsYouCount: Int {
        sessions.filter { activity($0) == .needsYou }.count
    }

    // MARK: - Decisions

    public func allow(_ request: PendingRequest) {
        respond(request, Decisions.allow(request), say: request.isPlan ? "Plan approved" : "Allowed")
    }

    public func alwaysAllow(_ request: PendingRequest) {
        respond(request, Decisions.alwaysAllow(request), say: "Always allowed")
    }

    public func deny(_ request: PendingRequest) {
        respond(request, Decisions.deny(note: denyNote[request.id] ?? ""), say: "Denied")
    }

    public func toggleSelection(_ id: String) {
        selected = selected == id ? nil : id
    }

    public func respond(_ request: PendingRequest, _ payload: [String: Any], say: String) {
        guard armed else { return }
        let session = request.sessionId
        feedback[session] = say
        answered.insert(request.id)

        // Write response file
        let out = paths.responses.appendingPathComponent("\(request.id).json")
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: out)
        }

        // Also mirror to legacy Claude responses path if request was there
        let legacyOut = PiuPaths.claudeHuddle.appendingPathComponent("responses").appendingPathComponent("\(request.id).json")
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: legacyOut)
        }

        // Remove from pending immediately
        pending.removeAll { $0.id == request.id }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.feedback[session] == say {
                self?.feedback[session] = nil
            }
        }
    }

    // MARK: - Scanning

    public func tick() {
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            let loadedSessions = Sessions.load(self.paths, isAlive: { pid in
                kill(pid, 0) == 0
            })

            // Load pending requests from both primary and legacy locations
            var loadedPending: [PendingRequest] = []
            for dir in [self.paths.pending, PiuPaths.claudeHuddle.appendingPathComponent("pending")] {
                let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
                for file in files where file.pathExtension == "json" {
                    if let json = readJSON(file), let req = PendingRequest(json: json), !self.answered.contains(req.id) {
                        if !loadedPending.contains(where: { $0.id == req.id }) {
                            loadedPending.append(req)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.now = Date()
                self.pending = loadedPending

                // Update sessions keeping steps
                self.sessions = loadedSessions.map { info in
                    var session = self.sessions.first(where: { $0.id == info.sessionId }) ?? AgentSession(info: info)
                    session.info = info
                    return session
                }
            }
        }
    }
}

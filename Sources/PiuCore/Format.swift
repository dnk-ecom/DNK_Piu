import Foundation

public enum Format {
    /// 950 → "950", 1234 → "1.2k", 84_300 → "84k", 1_300_000 → "1.3M".
    public static func tokens(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n < 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
        if n < 1_000_000 { return "\(Int((Double(n) / 1000).rounded()))k" }
        return String(format: "%.1fM", Double(n) / 1_000_000)
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// "resets in 2h 14m", "resets in 9m", "resets Tue 09:00" (more than a day away), "reset due".
    public static func reset(_ date: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return "" }
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return "reset due" }
        if seconds < 3600 { return "resets in \(max(1, seconds / 60))m" }
        if seconds < 86_400 { return "resets in \(seconds / 3600)h \((seconds % 3600) / 60)m" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE HH:mm"
        return "resets \(formatter.string(from: date))"
    }

    /// "now", "5m", "2h", "3d".
    public static func ago(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86_400)d"
    }

    public static func cost(_ usd: Double) -> String {
        String(format: "$%.2f", usd)
    }

    /// Clean formatting for MCP tools and Antigravity tools.
    public static func toolName(_ name: String) -> String {
        if name.hasPrefix("mcp__") {
            let parts = name.dropFirst(5).components(separatedBy: "__")
            guard parts.count >= 2 else { return name }
            return "\(parts[0]): \(parts.dropFirst().joined(separator: " ").replacingOccurrences(of: "_", with: " "))"
        }
        switch name {
        case "run_command": return "run command"
        case "write_file": return "write file"
        case "edit_file": return "edit file"
        case "read_file": return "read file"
        case "ask_question": return "question"
        case "search_web": return "search web"
        default: return name
        }
    }

    public static func oneLine(_ text: String, limit: Int = 160) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }
}

public enum Limits {
    static let labels: [(key: String, label: String)] = [
        ("five_hour", "5-hour limit"), ("seven_day", "Weekly limit"), ("spend_limit", "Spend limit"),
    ]

    public static func parse(_ rateLimits: [String: Any]?, now: Date) -> [LimitWindow] {
        guard let rateLimits else { return [] }
        return labels.compactMap { key, label in
            guard let window = rateLimits[key] as? [String: Any],
                  let used = (window["used_percentage"] as? NSNumber)?.doubleValue else { return nil }
            let resets = (window["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            if let resets, resets <= now { return nil }
            return LimitWindow(key: key, label: label, usedPercent: used, resetsAt: resets)
        }
    }
}

public enum StatusFiles {
    public static func parse(_ json: [String: Any], now: Date) -> SessionStatus? {
        guard let updated = (json["_updated_at"] as? NSNumber)?.doubleValue else { return nil }
        let context = json["context_window"] as? [String: Any]
        return SessionStatus(
            updatedAt: Date(timeIntervalSince1970: updated),
            model: (json["model"] as? [String: Any])?["display_name"] as? String,
            contextPercent: (context?["used_percentage"] as? NSNumber)?.doubleValue,
            contextSize: (context?["context_window_size"] as? NSNumber)?.intValue,
            costUSD: ((json["cost"] as? [String: Any])?["total_cost_usd"] as? NSNumber)?.doubleValue,
            limits: Limits.parse(json["rate_limits"] as? [String: Any], now: now))
    }

    public static func newestLimits(_ statuses: [SessionStatus]) -> (limits: [LimitWindow], updatedAt: Date)? {
        statuses.filter { !$0.limits.isEmpty }.max { $0.updatedAt < $1.updatedAt }.map { ($0.limits, $0.updatedAt) }
    }
}

public enum Sessions {
    public static func load(_ paths: PiuPaths, isAlive: (Int32) -> Bool) -> [SessionInfo] {
        var results: [SessionInfo] = []

        // 1. Scan primary DNK_Piu sessions
        let piuFiles = (try? FileManager.default.contentsOfDirectory(at: paths.sessions, includingPropertiesForKeys: nil)) ?? []
        for url in piuFiles where url.pathExtension == "json" {
            if let json = readJSON(url), let info = parse(json), isAlive(info.pid) {
                results.append(info)
            }
        }

        // 2. Scan legacy Claude Code sessions if folder exists
        let claudeSessions = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").appendingPathComponent("sessions")
        let claudeFiles = (try? FileManager.default.contentsOfDirectory(at: claudeSessions, includingPropertiesForKeys: nil)) ?? []
        for url in claudeFiles where url.pathExtension == "json" {
            if let json = readJSON(url), let info = parse(json), isAlive(info.pid), !results.contains(where: { $0.sessionId == info.sessionId }) {
                results.append(info)
            }
        }

        return results.sorted { $0.startedAt < $1.startedAt }
    }

    public static func parse(_ json: [String: Any]) -> SessionInfo? {
        guard let pid = (json["pid"] as? NSNumber)?.int32Value, let sessionId = json["sessionId"] as? String else { return nil }
        func date(_ key: String) -> Date {
            Date(timeIntervalSince1970: ((json[key] as? NSNumber)?.doubleValue ?? 0) / 1000)
        }
        let rawKind = json["agentKind"] as? String ?? json["agent"] as? String ?? ""
        let agentKind = AgentKind(rawValue: rawKind) ?? .unknown

        return SessionInfo(pid: pid, sessionId: sessionId, cwd: json["cwd"] as? String ?? "",
                           name: json["name"] as? String ?? "", rawStatus: json["status"] as? String ?? "",
                           entrypoint: json["entrypoint"] as? String ?? "",
                           agentKind: agentKind,
                           startedAt: date("startedAt"), updatedAt: date("updatedAt"))
    }
}

public enum Decisions {
    public static func allow(_ request: PendingRequest) -> [String: Any] {
        var payload: [String: Any] = ["behavior": "allow", "decision": "allow"]
        if request.isPlan { payload["updatedInput"] = request.toolInput }
        return payload
    }

    public static func alwaysAllow(_ request: PendingRequest) -> [String: Any] {
        var payload = allow(request)
        if !request.suggestions.isEmpty { payload["updatedPermissions"] = request.suggestions }
        return payload
    }

    public static func deny(note: String) -> [String: Any] {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["behavior": "deny", "decision": "deny", "message": trimmed.isEmpty ? "The user denied this in DNK_Piu." : trimmed]
    }

    public static func answer(_ request: PendingRequest, answers: [String: String]) -> [String: Any] {
        var input = request.toolInput
        input["answers"] = answers
        return ["behavior": "allow", "decision": "allow", "updatedInput": input]
    }

    public static func answerText(picked: [String], options: [QuestionOption], custom: String) -> String? {
        var parts = options.map(\.label).filter { picked.contains($0) }
        let typed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { parts.append(typed) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

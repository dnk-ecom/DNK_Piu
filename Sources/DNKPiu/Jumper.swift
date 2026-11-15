import AppKit
import Foundation

/// 1-Click window and tab activator for active agent sessions.
public enum Jumper {
    public static func activate(pid: Int32, cwd: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Try terminal activation by PID
            if activateTerminal(pid: pid) { return }

            // 2. Try editor / IDE activation by CWD
            activateFolder(cwd: cwd)
        }
    }

    private static func activateTerminal(pid: Int32) -> Bool {
        let script = """
        tell application "System Events"
            set procList to every process whose unix id is \(pid)
            if (count of procList) > 0 then
                set proc to item 1 of procList
                set frontmost of proc to true
                return true
            end if
        end tell
        return false
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            return result.booleanValue
        }
        return false
    }

    private static func activateFolder(cwd: String) {
        guard !cwd.isEmpty else { return }

        // Prefer Ghostty, Cursor, then VS Code
        let editors = ["com.mitchellh.ghostty", "com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode"]
        for bundleId in editors {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let conf = NSWorkspace.OpenConfiguration()
                conf.activates = true
                NSWorkspace.shared.open([URL(fileURLWithPath: cwd)], withApplicationAt: appUrl, configuration: conf)
                return
            }
        }
    }
}

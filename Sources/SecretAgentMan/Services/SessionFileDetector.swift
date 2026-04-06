import Foundation

/// Detects the actual Claude Code session ID by scanning session files
/// in ~/.claude/projects/<project-dir>/.
enum SessionFileDetector {
    /// Convert an agent's folder URL to the Claude project directory path.
    static func claudeProjectDir(for folder: URL) -> URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let projectKey = folder.path.replacingOccurrences(of: "/", with: "-")
        return home.appendingPathComponent(".claude/projects/\(projectKey)")
    }

    /// Check if a session file exists for the given session ID in an agent's project directory.
    static func sessionFileExists(_ sessionId: String, for folder: URL) -> Bool {
        sessionFileExists(sessionId, inDirectory: claudeProjectDir(for: folder))
    }

    /// Check if a session file exists in a directory.
    static func sessionFileExists(_ sessionId: String, inDirectory dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(sessionId).jsonl").path)
    }

    /// Find the most recently modified .jsonl session file for an agent folder.
    /// Returns the session ID (filename without extension) or nil.
    static func latestSessionId(for folder: URL) -> String? {
        latestSessionId(inDirectory: claudeProjectDir(for: folder))
    }

    /// Find the most recently modified .jsonl session file in a directory.
    static func latestSessionId(inDirectory dir: URL) -> String? {
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let sessions = entries.filter { $0.pathExtension == "jsonl" }

        let newest = sessions
            .compactMap { url -> (String, Date)? in
                guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                      let modified = attrs[.modificationDate] as? Date
                else { return nil }
                return (url.deletingPathExtension().lastPathComponent, modified)
            }
            .max(by: { $0.1 < $1.1 })

        return newest?.0
    }
}

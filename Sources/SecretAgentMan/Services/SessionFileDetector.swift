import Foundation

/// Detects the actual Claude Code session ID by scanning session files
/// or Codex session ID by scanning provider-specific local state.
enum SessionFileDetector {
    /// Convert an agent's folder URL to the Claude project directory path.
    static func claudeProjectDir(for folder: URL) -> URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let projectKey = folder.path.replacingOccurrences(of: "/", with: "-")
        return home.appendingPathComponent(".claude/projects/\(projectKey)")
    }

    static func sessionDirectory(for agent: Agent) -> URL {
        switch agent.provider {
        case .claude:
            claudeProjectDir(for: agent.folder)
        case .codex:
            codexSessionsDir()
        }
    }

    static func codexSessionsDir() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/sessions")
    }

    /// Check if a session file exists for the given session ID in an agent's project directory.
    static func sessionFileExists(_ sessionId: String, for agent: Agent) -> Bool {
        switch agent.provider {
        case .claude:
            sessionFileExists(sessionId, inDirectory: claudeProjectDir(for: agent.folder))
        case .codex:
            codexSessionFile(for: sessionId) != nil
        }
    }

    /// Check if a session file exists in a directory.
    static func sessionFileExists(_ sessionId: String, inDirectory dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(sessionId).jsonl").path)
    }

    /// Find the most recently modified .jsonl session file for an agent folder.
    /// Returns the session ID (filename without extension) or nil.
    static func latestSessionId(for agent: Agent) -> String? {
        switch agent.provider {
        case .claude:
            latestSessionId(inDirectory: claudeProjectDir(for: agent.folder))
        case .codex:
            latestCodexSessionId(for: agent.folder)
        }
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

    static func latestCodexSessionId(for folder: URL) -> String? {
        latestCodexSessionId(for: folder, inDirectory: codexSessionsDir())
    }

    static func latestCodexSessionId(for folder: URL, inDirectory dir: URL) -> String? {
        let sessions = codexSessionFiles(for: folder, inDirectory: dir)
        let newest = sessions.max { lhs, rhs in
            (lhs.modified ?? .distantPast) < (rhs.modified ?? .distantPast)
        }
        return newest?.id
    }

    static func codexSessionFileExists(_ sessionId: String, inDirectory dir: URL) -> Bool {
        codexSessionFile(for: sessionId, inDirectory: dir) != nil
    }

    static func parseCodexSessionMetaLine(_ line: String) -> (id: String, cwd: String)? {
        guard let lineData = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let type = json["type"] as? String,
              type == "session_meta",
              let payload = json["payload"] as? [String: Any],
              let id = payload["id"] as? String,
              let cwd = payload["cwd"] as? String
        else { return nil }

        return (id, cwd)
    }

    private static func codexSessionFile(for sessionId: String) -> URL? {
        codexSessionFile(for: sessionId, inDirectory: codexSessionsDir())
    }

    private static func codexSessionFile(for sessionId: String, inDirectory dir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if parseCodexSessionMeta(at: url)?.id == sessionId {
                return url
            }
        }
        return nil
    }

    private static func codexSessionFiles(for folder: URL) -> [(id: String, modified: Date?)] {
        codexSessionFiles(for: folder, inDirectory: codexSessionsDir())
    }

    private static func codexSessionFiles(for folder: URL, inDirectory dir: URL) -> [(id: String, modified: Date?)] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var matches: [(String, Date?)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl",
                  let meta = parseCodexSessionMeta(at: url),
                  URL(fileURLWithPath: meta.cwd).standardizedFileURL == folder.standardizedFileURL
            else { continue }

            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])).flatMap(\.contentModificationDate)
            matches.append((meta.id, modified))
        }
        return matches
    }

    private static func parseCodexSessionMeta(at url: URL) -> (id: String, cwd: String)? {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: 4096),
              let firstLine = String(data: data, encoding: .utf8)?
              .components(separatedBy: .newlines)
              .first
        else { return nil }

        return parseCodexSessionMetaLine(firstLine)
    }
}

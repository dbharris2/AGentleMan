import Foundation
@testable import SecretAgentMan
import Testing

struct SessionFileDetectorTests {
    @Test
    func claudeProjectDirMapsPathCorrectly() {
        let folder = URL(fileURLWithPath: "/Users/devon/projects/MyApp")
        let result = SessionFileDetector.claudeProjectDir(for: folder)
        #expect(result.path.hasSuffix(".claude/projects/-Users-devon-projects-MyApp"))
    }

    @Test
    func claudeProjectDirHandlesHomeDirectory() {
        let folder = URL(fileURLWithPath: NSHomeDirectory() + "/dmars/SecretAgentMan")
        let result = SessionFileDetector.claudeProjectDir(for: folder)
        let expected = NSHomeDirectory() + "/.claude/projects/-"
            + NSHomeDirectory().replacingOccurrences(of: "/", with: "-").dropFirst()
            + "-dmars-SecretAgentMan"
        #expect(result.path == expected)
    }

    @Test
    func latestSessionIdReturnsNewestFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create two session files with different modification dates
        let old = tmpDir.appendingPathComponent("old-session.jsonl")
        let new = tmpDir.appendingPathComponent("new-session.jsonl")
        try Data().write(to: old)
        // Small delay so modification dates differ
        Thread.sleep(forTimeInterval: 0.1)
        try Data().write(to: new)

        let result = SessionFileDetector.latestSessionId(inDirectory: tmpDir)
        #expect(result == "new-session")
    }

    @Test
    func latestSessionIdIgnoresNonJsonlFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data().write(to: tmpDir.appendingPathComponent("session.jsonl"))
        try Data().write(to: tmpDir.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(
            at: tmpDir.appendingPathComponent("some-dir"),
            withIntermediateDirectories: true
        )

        let result = SessionFileDetector.latestSessionId(inDirectory: tmpDir)
        #expect(result == "session")
    }

    @Test
    func latestSessionIdReturnsNilForEmptyDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let result = SessionFileDetector.latestSessionId(inDirectory: tmpDir)
        #expect(result == nil)
    }

    @Test
    func latestSessionIdReturnsNilForMissingDirectory() {
        let missing = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        let result = SessionFileDetector.latestSessionId(inDirectory: missing)
        #expect(result == nil)
    }

    // MARK: - sessionFileExists

    @Test
    func sessionFileExistsReturnsTrueWhenPresent() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data().write(to: tmpDir.appendingPathComponent("abc-123.jsonl"))

        #expect(SessionFileDetector.sessionFileExists("abc-123", inDirectory: tmpDir))
    }

    @Test
    func sessionFileExistsReturnsFalseWhenMissing() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data().write(to: tmpDir.appendingPathComponent("other-session.jsonl"))

        #expect(!SessionFileDetector.sessionFileExists("abc-123", inDirectory: tmpDir))
    }

    @Test
    func sessionFileExistsReturnsFalseForMissingDirectory() {
        let missing = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        #expect(!SessionFileDetector.sessionFileExists("abc-123", inDirectory: missing))
    }
}

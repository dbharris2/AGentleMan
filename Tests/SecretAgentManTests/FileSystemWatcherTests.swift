import Foundation
@testable import SecretAgentMan
import Testing

struct FileSystemWatcherTests {
    @Test
    @MainActor
    func vcsChangesTriggersMetadataCallback() async {
        let watcher = FileSystemWatcher()
        let dir = URL(fileURLWithPath: "/tmp/test-repo")

        var directoryChangedCalled = false
        var vcsMetadataChangedCalled = false

        watcher.onDirectoryChanged = { _ in directoryChangedCalled = true }
        watcher.onVCSMetadataChanged = { _ in vcsMetadataChangedCalled = true }

        watcher.handleEvents(directory: dir, paths: [
            "/tmp/test-repo/.jj/op/heads/123abc",
        ])

        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(!directoryChangedCalled)
        #expect(vcsMetadataChangedCalled)
    }

    @Test
    @MainActor
    func workingCopyChangesTriggersDirectoryCallback() async {
        let watcher = FileSystemWatcher()
        let dir = URL(fileURLWithPath: "/tmp/test-repo")

        var directoryChangedCalled = false
        var vcsMetadataChangedCalled = false

        watcher.onDirectoryChanged = { _ in directoryChangedCalled = true }
        watcher.onVCSMetadataChanged = { _ in vcsMetadataChangedCalled = true }

        watcher.handleEvents(directory: dir, paths: [
            "/tmp/test-repo/src/main.swift",
        ])

        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(directoryChangedCalled)
        #expect(!vcsMetadataChangedCalled)
    }

    @Test
    @MainActor
    func mixedChangesTriggersBothCallbacks() async {
        let watcher = FileSystemWatcher()
        let dir = URL(fileURLWithPath: "/tmp/test-repo")

        var directoryChangedCalled = false
        var vcsMetadataChangedCalled = false

        watcher.onDirectoryChanged = { _ in directoryChangedCalled = true }
        watcher.onVCSMetadataChanged = { _ in vcsMetadataChangedCalled = true }

        watcher.handleEvents(directory: dir, paths: [
            "/tmp/test-repo/.jj/op/heads/123abc",
            "/tmp/test-repo/src/main.swift",
        ])

        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(directoryChangedCalled)
        #expect(vcsMetadataChangedCalled)
    }

    @Test
    @MainActor
    func gitChangesTriggersMetadataCallback() async {
        let watcher = FileSystemWatcher()
        let dir = URL(fileURLWithPath: "/tmp/test-repo")

        var directoryChangedCalled = false
        var vcsMetadataChangedCalled = false

        watcher.onDirectoryChanged = { _ in directoryChangedCalled = true }
        watcher.onVCSMetadataChanged = { _ in vcsMetadataChangedCalled = true }

        watcher.handleEvents(directory: dir, paths: [
            "/tmp/test-repo/.git/refs/heads/main",
        ])

        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(!directoryChangedCalled)
        #expect(vcsMetadataChangedCalled)
    }

    @Test
    @MainActor
    func noEventsTriggersNothing() async {
        let watcher = FileSystemWatcher()
        let dir = URL(fileURLWithPath: "/tmp/test-repo")

        var directoryChangedCalled = false
        var vcsMetadataChangedCalled = false

        watcher.onDirectoryChanged = { _ in directoryChangedCalled = true }
        watcher.onVCSMetadataChanged = { _ in vcsMetadataChangedCalled = true }

        watcher.handleEvents(directory: dir, paths: [])

        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(!directoryChangedCalled)
        #expect(!vcsMetadataChangedCalled)
    }
}

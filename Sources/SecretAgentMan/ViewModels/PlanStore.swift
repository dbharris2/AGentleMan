import Foundation
import SwiftUI

struct PlanFile: Identifiable, Hashable {
    let url: URL
    let title: String
    let filename: String
    let modified: Date?

    var id: URL {
        url
    }
}

@MainActor
@Observable
final class PlanStore {
    var plans: [PlanFile] = []

    @ObservationIgnored private let plansDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/plans")
    @ObservationIgnored private var fileWatcher = FileSystemWatcher()

    func start() {
        try? FileManager.default.createDirectory(
            at: plansDir,
            withIntermediateDirectories: true
        )
        fileWatcher.onDirectoryChanged = { [weak self] _ in
            self?.refresh()
        }
        fileWatcher.watch(directory: plansDir)
        refresh()
    }

    func stop() {
        fileWatcher.unwatchAll()
    }

    func refresh() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: plansDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            plans = []
            return
        }

        plans = files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> PlanFile? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                    return nil
                }
                let title = Self.extractTitle(from: content)
                    ?? url.deletingPathExtension().lastPathComponent
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                return PlanFile(
                    url: url,
                    title: title,
                    filename: url.lastPathComponent,
                    modified: modified
                )
            }
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    func deletePlan(_ plan: PlanFile) {
        try? FileManager.default.removeItem(at: plan.url)
        refresh()
    }

    private static func extractTitle(from content: String) -> String? {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }
}

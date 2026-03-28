import SwiftUI

struct ChangesView: View {
    let changes: [FileChange]
    let fullDiff: String

    var body: some View {
        if changes.isEmpty {
            ContentUnavailableView(
                "No Changes",
                systemImage: "doc.text",
                description: Text("No file changes detected in this directory")
            )
        } else {
            VSplitView {
                fileList
                    .frame(minHeight: 100)

                diffView
                    .frame(minHeight: 200)
            }
        }
    }

    private var fileList: some View {
        List {
            Section("Changed Files (\(changes.count))") {
                ForEach(changes) { change in
                    HStack {
                        Text(change.status.label)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(statusColor(change.status))
                            .frame(width: 16)

                        Text(change.path)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        HStack(spacing: 4) {
                            if change.insertions > 0 {
                                Text("+\(change.insertions)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            if change.deletions > 0 {
                                Text("-\(change.deletions)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .listStyle(.inset)
    }

    private var diffView: some View {
        ScrollView {
            Text(fullDiff.isEmpty ? "No diff output" : fullDiff)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(.background.secondary)
    }

    private func statusColor(_ status: FileChange.ChangeStatus) -> Color {
        switch status {
        case .added: .green
        case .modified: .orange
        case .deleted: .red
        case .renamed: .blue
        }
    }
}

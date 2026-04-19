import SwiftUI

struct ScriptRunnerPopover: View {
    let scripts: [ProjectScript]
    let onRun: (ProjectScript) -> Void

    private var grouped: [(source: ProjectScript.ScriptSource, scripts: [ProjectScript])] {
        let dict = Dictionary(grouping: scripts) { $0.source }
        return ProjectScript.ScriptSource.allCases.compactMap { source in
            guard let items = dict[source], !items.isEmpty else { return nil }
            return (source: source, scripts: items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Scripts")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xl)
            Divider()

            if scripts.isEmpty {
                Text("No scripts detected")
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(grouped, id: \.source) { group in
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: group.source.icon)
                                        .scaledFont(size: 9)
                                    Text(group.source.rawValue)
                                        .scaledFont(size: 11, weight: .medium)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, Spacing.xl)
                                .padding(.bottom, Spacing.xs)

                                ForEach(group.scripts) { script in
                                    ScriptRow(script: script, onRun: onRun)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(minWidth: 200)
    }
}

private struct ScriptRow: View {
    let script: ProjectScript
    let onRun: (ProjectScript) -> Void

    var body: some View {
        Button {
            onRun(script)
        } label: {
            HStack {
                Text(script.name)
                    .scaledFont(size: 12)
                Spacer()
                Image(systemName: "play.fill")
                    .scaledFont(size: 9)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .hoverHighlight(cornerRadius: 0)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct SkillsPopover: View {
    let skills: [SkillInfo]
    var onSend: ((SkillInfo) -> Void)?

    private var grouped: [(source: String, skills: [SkillInfo])] {
        let dict = Dictionary(grouping: skills) { $0.source }
        return dict.keys.sorted { lhs, rhs in
            // "local" sorts first, then alphabetical
            if lhs == "local" { return true }
            if rhs == "local" { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.compactMap { source in
            guard let items = dict[source] else { return nil }
            return (source: source, skills: items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Skills")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xl)
            Divider()

            if skills.isEmpty {
                Text("No skills available")
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(grouped, id: \.source) { group in
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: group.source == "local" ? "folder" : "puzzlepiece.extension")
                                        .scaledFont(size: 9)
                                    Text(group.source)
                                        .scaledFont(size: 11, weight: .medium)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, Spacing.xl)
                                .padding(.bottom, Spacing.xs)

                                ForEach(group.skills) { skill in
                                    SkillRow(skill: skill, onSend: onSend)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(.vertical, Spacing.xl)
        .frame(minWidth: 240, maxWidth: 360)
    }
}

private struct SkillRow: View {
    let skill: SkillInfo
    var onSend: ((SkillInfo) -> Void)?

    var body: some View {
        Button {
            onSend?(skill)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("/\(skill.name)")
                        .scaledFont(size: 12, weight: .medium)
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .scaledFont(size: 10)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "text.insert")
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

import SwiftUI

struct UsageRing: View {
    let percent: Double
    var diameter: CGFloat = 14
    var lineWidth: CGFloat = 2

    @Environment(\.appTheme) private var theme

    private var color: Color {
        if percent > 80 { return theme.red }
        if percent > 50 { return theme.yellow }
        return theme.green
    }

    private var progress: Double {
        min(max(percent / 100, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Rectangle())
    }
}

struct UsagePopover: View {
    let limits: AgentRateLimits
    let provider: AgentProvider
    @Environment(\.appTheme) private var theme

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("API Usage — \(provider.displayName)")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(.secondary)

            Divider()

            usageRow(limits.shortWindow)
            usageRow(limits.longWindow)
        }
        .padding(Spacing.xl)
        .frame(minWidth: 200)
    }

    private func usageRow(_ window: WindowUsage) -> some View {
        let percent = window.usedPercent
        let color: Color = percent > 80 ? theme.red : percent > 50 ? theme.yellow : theme.green

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(window.windowLabel) window")
                    .scaledFont(size: 11, weight: .medium)
                Spacer()
                Text(verbatim: "\(Int(percent))%")
                    .scaledFont(size: 11, weight: .medium)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(percent / 100, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            if let resetsAt = window.resetsAt {
                let formatter =
                    if Calendar.current.isDate(resetsAt, inSameDayAs: Date()) {
                        Self.timeFormatter
                    } else {
                        Self.dateTimeFormatter
                    }
                Text("Resets at \(formatter.string(from: resetsAt))")
                    .scaledFont(size: 10)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

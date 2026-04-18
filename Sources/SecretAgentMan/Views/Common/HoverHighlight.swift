import SwiftUI

struct HoverHighlight: ViewModifier {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = 6
    @State private var isHovered = false
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
            )
            .onHover { isHovered = $0 }
    }

    private var fillColor: Color {
        if isSelected { return theme.accent.opacity(0.2) }
        if isHovered { return theme.foreground.opacity(0.06) }
        return .clear
    }
}

extension View {
    func hoverHighlight(isSelected: Bool = false, cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverHighlight(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

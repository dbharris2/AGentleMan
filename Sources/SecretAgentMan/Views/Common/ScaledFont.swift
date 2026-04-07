import SwiftUI

extension EnvironmentValues {
    @Entry var fontScale: Double = 1.0
}

extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design? = nil
    ) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.fontScale) private var fontScale
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design?

    func body(content: Content) -> some View {
        let scaled = size * fontScale
        if let design {
            content.font(.system(size: scaled, weight: weight, design: design))
        } else {
            content.font(.system(size: scaled, weight: weight))
        }
    }
}

import SwiftUI

struct AgentProviderIconView: View {
    let provider: AgentProvider
    let size: CGFloat

    init(provider: AgentProvider, size: CGFloat = 24) {
        self.provider = provider
        self.size = size
    }

    var body: some View {
        if let assetName = provider.iconAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.25)
                    .fill(Color.accentColor.opacity(0.15))
                Image(systemName: provider.symbolName)
                    .scaledFont(size: size * 0.5, weight: .semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: size, height: size)
        }
    }
}

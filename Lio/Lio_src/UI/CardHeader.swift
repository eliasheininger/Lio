import SwiftUI

/// "Lio" logo + name header used at the top of expanded card states
struct CardHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            LogoImage(size: 16)
            Text("Lio")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.aBlue)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }
}

/// Thin full-width divider used between card sections
struct CardDivider: View {
    var body: some View {
        Color.black.opacity(0.10)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

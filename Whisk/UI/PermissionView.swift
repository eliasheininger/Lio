import SwiftUI

struct PermissionView: View {
    var app:     String
    var message: String
    var onDeny:   (() -> Void)? = nil
    var onAccept: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            CardHeader()
            CardDivider()

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.aPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                // Deny
                Button("Deny") { onDeny?() }
                    .buttonStyle(WhiskButtonStyle(primary: false))

                // Accept
                Button("Accept") { onAccept?() }
                    .buttonStyle(WhiskButtonStyle(primary: true))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: PANEL_W)
    }
}

// MARK: - Button style
struct WhiskButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(primary ? .white : .aPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(primary ? Color.aBlue : Color.black.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

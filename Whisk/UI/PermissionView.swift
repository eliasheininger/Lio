import SwiftUI

struct PermissionView: View {
    var app:         String
    var message:     String
    var acceptLabel: String = "Accept"
    var denyLabel:   String = "Deny"
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

            VStack(spacing: 8) {
                // Accept
                Button(acceptLabel) { onAccept?() }
                    .buttonStyle(WhiskButtonStyle(primary: true))

                // Deny
                Button(denyLabel) { onDeny?() }
                    .buttonStyle(WhiskButtonStyle(primary: false))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: PANEL_W)
    }
}

// MARK: - Button style
struct WhiskButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(primary ? .white : .aPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                Capsule()
                    .fill(primary ? Color.aBlue : Color.black.opacity(0.08))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

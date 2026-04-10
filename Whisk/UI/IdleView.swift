import SwiftUI

struct IdleView: View {
    var label:  String = "Hold to speak"
    var detail: String = "Right Option  ⌥"

    var body: some View {
        HStack(spacing: 0) {
            // Left: logo icon
            LogoImage(size: 20)
                .frame(width: DIV_X)

            // Vertical divider
            Color.black.opacity(0.10)
                .frame(width: 0.5, height: PILL_H - 28)

            // Right: labels
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.aPrimary)
                Text(detail)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(Color(white: 0.38))
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)

            Spacer(minLength: 0)
        }
        .frame(width: PANEL_W, height: PILL_H)
    }
}

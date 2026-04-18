import SwiftUI

struct ActionView: View {
    var label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: actionIconName(for: label))
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.35))
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: PANEL_W, height: PILL_H)
    }
}

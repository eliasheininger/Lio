import SwiftUI

struct TranscriptView: View {
    var text: String

    var body: some View {
        VStack(spacing: 0) {
            CardHeader()
            CardDivider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14))
                    .foregroundColor(.aSecondary)
                    .padding(.top, 1)

                Text(text)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(.aPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: PANEL_W)
    }
}

import SwiftUI

struct TranscriptView: View {
    var text: String

    private let dotSize:  CGFloat = 24
    private let lineWidth: CGFloat = 1.5
    private let iconColor = Color(white: 0.72)

    var body: some View {
        VStack(spacing: 0) {
            CardHeader()
            CardDivider()

            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(iconColor, lineWidth: lineWidth)
                        .frame(width: dotSize, height: dotSize)
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .frame(width: dotSize, height: dotSize)

                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.aPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: dotSize, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: PANEL_W)
    }
}

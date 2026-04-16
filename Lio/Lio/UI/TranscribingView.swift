import SwiftUI

struct TranscribingView: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 0) {
            // Pulsing blue dot
            Circle()
                .fill(Color.aBlue)
                .frame(width: 12, height: 12)
                .scaleEffect(pulsing ? 0.68 : 1.0)
                .animation(
                    .easeInOut(duration: 0.82).repeatForever(autoreverses: true),
                    value: pulsing
                )
                .frame(width: DIV_X)
                .onAppear { pulsing = true }

            Color.black.opacity(0.10)
                .frame(width: 0.5, height: PILL_H - 28)

            Text("Transcribing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .padding(.leading, 14)

            Spacer(minLength: 0)
        }
        .frame(width: PANEL_W, height: PILL_H)
    }
}

import SwiftUI

struct RecordingView: View {
    var level: Double   // live RMS 0.0–1.0

    private let leftW: CGFloat = 60
    private let btnSz: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            // Red stop button
            ZStack {
                Circle()
                    .fill(Color.aRed)
                    .frame(width: btnSz, height: btnSz)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
            }
            .frame(width: leftW)

            // Vertical divider
            Color.black.opacity(0.10)
                .frame(width: 0.5, height: PILL_H - 28)

            // Waveform
            WaveformBarsView(targetLevel: level)
                .frame(maxWidth: .infinity)
        }
        .frame(width: PANEL_W, height: PILL_H)
    }
}

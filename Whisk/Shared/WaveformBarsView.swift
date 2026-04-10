import SwiftUI

/// 24-bar waveform animated via SwiftUI's native animation system.
/// Uses onChange + withAnimation so displayLevel is properly interpolated.
struct WaveformBarsView: View {
    var targetLevel: Double   // 0.0–1.0, updated externally

    @State private var displayLevel: Double = 0

    private let barCount  = 24
    private let barW: CGFloat = 3
    private let gap:  CGFloat = 3
    private let minScale  = 0.10

    private var multipliers: [Double] {
        (0..<barCount).map { i in
            0.18 + 0.82 * sin(.pi * Double(i) / Double(barCount - 1))
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let total  = CGFloat(barCount) * barW + CGFloat(barCount - 1) * gap
            let startX = (size.width - total) / 2
            let cy     = size.height / 2
            let maxH   = size.height * 0.80

            for i in 0..<barCount {
                let scale = minScale + (1 - minScale) * displayLevel * multipliers[i]
                let h     = maxH * CGFloat(scale)
                let x     = startX + CGFloat(i) * (barW + gap)
                let rect  = CGRect(x: x, y: cy - h / 2, width: barW, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: barW / 2),
                         with: .color(Color(white: 0.12, opacity: 0.9)))
            }
        }
        // Fast attack, slow decay — driven by SwiftUI's animation system
        .onChange(of: targetLevel) { newVal in
            let duration = newVal > displayLevel ? 0.05 : 0.25
            withAnimation(.easeOut(duration: duration)) {
                displayLevel = newVal
            }
        }
    }
}

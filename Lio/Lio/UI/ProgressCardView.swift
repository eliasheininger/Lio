import SwiftUI

struct ProgressCardView: View {
    var steps:          [StepItem]
    var completedCount: Int
    var summary:        String

    var body: some View {
        VStack(spacing: 0) {
            CardHeader()
            CardDivider()

            VStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    StepRow(
                        step:   steps[i],
                        isLast: i == steps.indices.last
                    )
                }
            }
            .padding(.top, 10)
            .padding(.bottom, summary.isEmpty ? 10 : 4)

            if !summary.isEmpty {
                CardDivider()
                HStack(alignment: .top) {
                    Text(summary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.aPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .frame(width: PANEL_W)
    }
}

private struct StepRow: View {
    let step:   StepItem
    let isLast: Bool

    private let dotSize:   CGFloat = 24
    private let iconSize:  CGFloat = 11
    private let rowHeight: CGFloat = 38
    private let lineWidth: CGFloat = 1
    private let iconColor  = Color(white: 0.72)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {

            // ── Icon column ──────────────────────────────────────
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .strokeBorder(iconColor, lineWidth: lineWidth)
                        .frame(width: dotSize, height: dotSize)

                    if step.completed {
                        Image(systemName: actionIconName(for: step.text))
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(iconColor)
                    } else {
                        ProgressView()
                            .scaleEffect(0.45)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(width: dotSize, height: dotSize)

                if !isLast {
                    Rectangle()
                        .fill(Color(white: 0.78))
                        .frame(width: lineWidth, height: rowHeight - dotSize)
                }
            }
            .frame(width: dotSize)

            // ── Label ────────────────────────────────────────────
            Text(step.text)
                .font(.system(size: 12.5))
                .foregroundColor(step.completed ? Color(white: 0.52) : Color(white: 0.08))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: dotSize)
        }
        .padding(.horizontal, 16)
        .frame(height: rowHeight)
    }
}

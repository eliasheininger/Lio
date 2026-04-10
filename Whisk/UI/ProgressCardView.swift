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
                ForEach(steps) { step in
                    StepRow(step: step)
                }
            }
            .padding(.vertical, 4)

            if !summary.isEmpty {
                CardDivider()
                HStack {
                    Text(summary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.aPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
            }
        }
        .frame(width: PANEL_W)
    }
}

private struct StepRow: View {
    var step: StepItem

    var body: some View {
        HStack(spacing: 8) {
            if step.completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.aGreen)
                    .frame(width: 16)
            } else {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 16, height: 16)
            }

            Text(step.text)
                .font(.system(size: 12.5))
                .foregroundColor(step.completed ? Color(white: 0.55) : .aPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
    }
}

import SwiftUI

struct SuccessView: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.aGreen)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: PANEL_W, height: PILL_H)
    }
}

struct ErrorView: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.aRed)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: PANEL_W, height: PILL_H)
    }
}

import SwiftUI

struct SuccessView: View {
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.aBlue)
                .frame(height: 20)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(width: PANEL_W)
    }
}

struct ErrorView: View {
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.aRed)
                .frame(height: 20)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.aPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(width: PANEL_W)
    }
}

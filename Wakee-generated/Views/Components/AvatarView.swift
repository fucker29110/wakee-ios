import SwiftUI

struct AvatarView: View {
    let name: String
    let photoURL: String?
    var size: CGFloat = 40

    private static let colors: [Color] = [
        Color(hex: "#FF6B35"), Color(hex: "#E91E63"), Color(hex: "#9C27B0"),
        Color(hex: "#2196F3"), Color(hex: "#00BCD4"), Color(hex: "#4CAF50"),
        Color(hex: "#FF9800")
    ]

    private var initials: String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }
        return String(chars).uppercased()
    }

    private var avatarColor: Color {
        var hash = 0
        for char in name.unicodeScalars {
            hash = Int(char.value) &+ ((hash &<< 5) &- hash)
        }
        return Self.colors[abs(hash) % Self.colors.count]
    }

    var body: some View {
        if let photoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    fallbackView
                default:
                    fallbackView.opacity(0.5)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

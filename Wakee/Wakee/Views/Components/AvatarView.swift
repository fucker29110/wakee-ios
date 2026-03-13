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

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if photoURL != nil {
                fallbackView.opacity(0.5)
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: photoURL) {
            guard let photoURL, let url = URL(string: photoURL) else {
                image = nil
                return
            }
            // キャッシュから即座に表示
            if let cached = ImageCache.shared.cachedImage(url: photoURL, size: size) {
                image = cached
                return
            }
            image = await ImageCache.shared.loadImage(url: url, size: size)
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

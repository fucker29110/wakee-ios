import SwiftUI

struct GoogleLogoView: View {
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 48
            // Yellow
            let yellowPath = Path { p in
                p.move(to: CGPoint(x: 43.611 * scale, y: 20.083 * scale))
                p.addLine(to: CGPoint(x: 42 * scale, y: 20.083 * scale))
                p.addLine(to: CGPoint(x: 42 * scale, y: 20 * scale))
                p.addLine(to: CGPoint(x: 24 * scale, y: 20 * scale))
                p.addLine(to: CGPoint(x: 24 * scale, y: 28 * scale))
                p.addLine(to: CGPoint(x: 35.303 * scale, y: 28 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 36 * scale),
                           control1: CGPoint(x: 33.654 * scale, y: 32.657 * scale),
                           control2: CGPoint(x: 29.223 * scale, y: 36 * scale))
                p.addCurve(to: CGPoint(x: 12 * scale, y: 24 * scale),
                           control1: CGPoint(x: 17.373 * scale, y: 36 * scale),
                           control2: CGPoint(x: 12 * scale, y: 30.627 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 12 * scale),
                           control1: CGPoint(x: 12 * scale, y: 17.373 * scale),
                           control2: CGPoint(x: 17.373 * scale, y: 12 * scale))
                p.addCurve(to: CGPoint(x: 31.961 * scale, y: 15.039 * scale),
                           control1: CGPoint(x: 27.059 * scale, y: 12 * scale),
                           control2: CGPoint(x: 29.842 * scale, y: 13.154 * scale))
                p.addLine(to: CGPoint(x: 37.618 * scale, y: 9.382 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 4 * scale),
                           control1: CGPoint(x: 34.046 * scale, y: 6.053 * scale),
                           control2: CGPoint(x: 29.268 * scale, y: 4 * scale))
                p.addCurve(to: CGPoint(x: 4 * scale, y: 24 * scale),
                           control1: CGPoint(x: 12.955 * scale, y: 4 * scale),
                           control2: CGPoint(x: 4 * scale, y: 12.955 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 44 * scale),
                           control1: CGPoint(x: 4 * scale, y: 35.045 * scale),
                           control2: CGPoint(x: 12.955 * scale, y: 44 * scale))
                p.addCurve(to: CGPoint(x: 44 * scale, y: 24 * scale),
                           control1: CGPoint(x: 35.045 * scale, y: 44 * scale),
                           control2: CGPoint(x: 44 * scale, y: 35.045 * scale))
                p.addCurve(to: CGPoint(x: 43.611 * scale, y: 20.083 * scale),
                           control1: CGPoint(x: 44 * scale, y: 22.659 * scale),
                           control2: CGPoint(x: 43.862 * scale, y: 21.35 * scale))
                p.closeSubpath()
            }
            context.fill(yellowPath, with: .color(Color(hex: "#FFC107")))

            // Red
            let redPath = Path { p in
                p.move(to: CGPoint(x: 6.306 * scale, y: 14.691 * scale))
                p.addLine(to: CGPoint(x: 12.877 * scale, y: 19.51 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 12 * scale),
                           control1: CGPoint(x: 14.655 * scale, y: 15.108 * scale),
                           control2: CGPoint(x: 18.961 * scale, y: 12 * scale))
                p.addCurve(to: CGPoint(x: 31.961 * scale, y: 15.039 * scale),
                           control1: CGPoint(x: 27.059 * scale, y: 12 * scale),
                           control2: CGPoint(x: 29.842 * scale, y: 13.154 * scale))
                p.addLine(to: CGPoint(x: 37.618 * scale, y: 9.382 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 4 * scale),
                           control1: CGPoint(x: 34.046 * scale, y: 6.053 * scale),
                           control2: CGPoint(x: 29.268 * scale, y: 4 * scale))
                p.addCurve(to: CGPoint(x: 6.306 * scale, y: 14.691 * scale),
                           control1: CGPoint(x: 16.318 * scale, y: 4 * scale),
                           control2: CGPoint(x: 9.656 * scale, y: 8.337 * scale))
                p.closeSubpath()
            }
            context.fill(redPath, with: .color(Color(hex: "#FF3D00")))

            // Green
            let greenPath = Path { p in
                p.move(to: CGPoint(x: 24 * scale, y: 44 * scale))
                p.addCurve(to: CGPoint(x: 37.409 * scale, y: 38.808 * scale),
                           control1: CGPoint(x: 29.166 * scale, y: 44 * scale),
                           control2: CGPoint(x: 33.86 * scale, y: 42.023 * scale))
                p.addLine(to: CGPoint(x: 31.219 * scale, y: 33.57 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 36 * scale),
                           control1: CGPoint(x: 29.211 * scale, y: 35.091 * scale),
                           control2: CGPoint(x: 26.718 * scale, y: 36 * scale))
                p.addCurve(to: CGPoint(x: 12.717 * scale, y: 28.054 * scale),
                           control1: CGPoint(x: 18.798 * scale, y: 36 * scale),
                           control2: CGPoint(x: 14.381 * scale, y: 32.683 * scale))
                p.addLine(to: CGPoint(x: 6.195 * scale, y: 33.079 * scale))
                p.addCurve(to: CGPoint(x: 24 * scale, y: 44 * scale),
                           control1: CGPoint(x: 9.505 * scale, y: 39.556 * scale),
                           control2: CGPoint(x: 16.227 * scale, y: 44 * scale))
                p.closeSubpath()
            }
            context.fill(greenPath, with: .color(Color(hex: "#4CAF50")))

            // Blue
            let bluePath = Path { p in
                p.move(to: CGPoint(x: 43.611 * scale, y: 20.083 * scale))
                p.addLine(to: CGPoint(x: 42 * scale, y: 20.083 * scale))
                p.addLine(to: CGPoint(x: 42 * scale, y: 20 * scale))
                p.addLine(to: CGPoint(x: 24 * scale, y: 20 * scale))
                p.addLine(to: CGPoint(x: 24 * scale, y: 28 * scale))
                p.addLine(to: CGPoint(x: 35.303 * scale, y: 28 * scale))
                p.addCurve(to: CGPoint(x: 31.216 * scale, y: 33.571 * scale),
                           control1: CGPoint(x: 34.331 * scale, y: 30.164 * scale),
                           control2: CGPoint(x: 32.933 * scale, y: 32.041 * scale))
                p.addLine(to: CGPoint(x: 31.219 * scale, y: 33.569 * scale))
                p.addLine(to: CGPoint(x: 37.409 * scale, y: 38.807 * scale))
                p.addCurve(to: CGPoint(x: 44 * scale, y: 24 * scale),
                           control1: CGPoint(x: 36.971 * scale, y: 39.205 * scale),
                           control2: CGPoint(x: 44 * scale, y: 34 * scale))
                p.addCurve(to: CGPoint(x: 43.611 * scale, y: 20.083 * scale),
                           control1: CGPoint(x: 44 * scale, y: 22.659 * scale),
                           control2: CGPoint(x: 43.862 * scale, y: 21.35 * scale))
                p.closeSubpath()
            }
            context.fill(bluePath, with: .color(Color(hex: "#1976D2")))
        }
        .frame(width: size, height: size)
    }
}

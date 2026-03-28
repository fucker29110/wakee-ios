import SwiftUI
import UIKit

struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    @State private var circleSize: CGFloat = 0
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        VStack(spacing: 0) {
            // Crop area
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.85

                ZStack {
                    Color.black

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value.magnification
                                        scale = min(max(newScale, minScale), maxScale)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        clampOffset(circleSize: size)
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        clampOffset(circleSize: size)
                                    }
                            )
                        )
                        .clipShape(Circle())

                    // Dark overlay with circular hole
                    CircleCutout(circleSize: size)
                        .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                    // Circle border
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: size, height: size)
                        .allowsHitTesting(false)
                }
                .onAppear { circleSize = size }
                .onChange(of: geo.size) { circleSize = min($1.width, $1.height) * 0.85 }
            }

            // Bottom bar
            HStack {
                Button(lang.l("crop.cancel")) {
                    onCancel()
                }
                .font(.system(size: AppTheme.FontSize.md))
                .foregroundColor(.white)

                Spacer()

                Button(lang.l("crop.done")) {
                    let cropped = cropImage(circleSize: circleSize)
                    onCrop(cropped)
                }
                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                .foregroundColor(AppTheme.Colors.accent)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func clampOffset(circleSize: CGFloat) {
        let maxOffset = (circleSize * (scale - 1)) / 2
        let clampedX = min(max(offset.width, -maxOffset), maxOffset)
        let clampedY = min(max(offset.height, -maxOffset), maxOffset)
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: clampedX, height: clampedY)
            lastOffset = offset
        }
    }

    /// Normalize orientation to .up so CGImage pixel data matches displayed layout.
    private func normalizeOrientation(_ src: UIImage) -> UIImage {
        guard src.imageOrientation != .up else { return src }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: src.size, format: format)
        return renderer.image { _ in
            src.draw(in: CGRect(origin: .zero, size: src.size))
        }
    }

    private func cropImage(circleSize: CGFloat) -> UIImage {
        let normalized = normalizeOrientation(image)
        let imageSize = normalized.size
        let imageAspect = imageSize.width / imageSize.height

        // The image is displayed with scaledToFill in a circleSize x circleSize frame
        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        if imageAspect > 1 {
            displayedHeight = circleSize
            displayedWidth = circleSize * imageAspect
        } else {
            displayedWidth = circleSize
            displayedHeight = circleSize / imageAspect
        }

        // Scale factor from display to actual image pixels
        let pixelScale = imageSize.width / displayedWidth

        // The visible circle center in the image, accounting for zoom and offset
        let centerXInDisplay = displayedWidth / 2 - offset.width / scale
        let centerYInDisplay = displayedHeight / 2 - offset.height / scale
        let visibleRadius = (circleSize / 2) / scale

        let cropX = (centerXInDisplay - visibleRadius) * pixelScale
        let cropY = (centerYInDisplay - visibleRadius) * pixelScale
        let cropSize = visibleRadius * 2 * pixelScale

        let outputSize: CGFloat = 800
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { ctx in
            // Clip to circle
            let clipRect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            ctx.cgContext.addEllipse(in: clipRect)
            ctx.cgContext.clip()

            // Draw the cropped portion
            let sourceRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
            if let cgImage = normalized.cgImage?.cropping(to: sourceRect) {
                UIImage(cgImage: cgImage).draw(in: clipRect)
            } else {
                normalized.draw(in: clipRect)
            }
        }
    }
}

// MARK: - Circle Cutout Shape

private struct CircleCutout: Shape {
    let circleSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let circleRect = CGRect(
            x: rect.midX - circleSize / 2,
            y: rect.midY - circleSize / 2,
            width: circleSize,
            height: circleSize
        )
        path.addEllipse(in: circleRect)
        return path
    }
}

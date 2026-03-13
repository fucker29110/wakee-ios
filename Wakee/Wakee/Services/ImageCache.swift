import UIKit
import ImageIO

/// メモリ効率の良い画像キャッシュ
/// ダウンサンプリングで表示サイズに合わせた画像を保持し、メモリ使用量を大幅に削減
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 80
        c.totalCostLimit = 30 * 1024 * 1024 // 30MB
        return c
    }()

    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    private init() {}

    /// キャッシュキー（URL + サイズ）
    private func cacheKey(url: String, size: CGFloat) -> NSString {
        "\(url)_\(Int(size))" as NSString
    }

    /// キャッシュから画像を取得（なければnil）
    func cachedImage(url: String, size: CGFloat) -> UIImage? {
        cache.object(forKey: cacheKey(url: url, size: size))
    }

    /// 画像をダウンロードしてダウンサンプリング、キャッシュに保存
    func loadImage(url: URL, size: CGFloat) async -> UIImage? {
        let key = cacheKey(url: url.absoluteString, size: size)

        // キャッシュヒット
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // 同じURLへの重複リクエストを防止
        let taskKey = key as String
        lock.lock()
        if let existing = inflightTasks[taskKey] {
            lock.unlock()
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            defer {
                lock.lock()
                inflightTasks.removeValue(forKey: taskKey)
                lock.unlock()
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return nil }
                guard let image = Self.downsample(data: data, maxPixelSize: size) else { return nil }
                let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                cache.setObject(image, forKey: key, cost: cost)
                return image
            } catch {
                return nil
            }
        }
        inflightTasks[taskKey] = task
        lock.unlock()

        return await task.value
    }

    /// ImageIO を使って指定サイズにダウンサンプリング（フルデコードを避ける）
    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let maxDimension = maxPixelSize * scale

        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

import Foundation

/// 録音音声のローカルキャッシュ管理
/// eventIdをキーにcachesDirectoryへ保存し、通知受信時にダウンロード不要で即座再生を可能にする
final class AlarmAudioCache {
    static let shared = AlarmAudioCache()
    private init() {}

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("alarm_audio", isDirectory: true)
    }

    /// 録音音声をキャッシュに保存（送信時に呼ぶ）
    func save(data: Data, for eventId: String) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let fileURL = cacheDirectory.appendingPathComponent("\(eventId).m4a")
            try data.write(to: fileURL)
            // audioURL → eventId の逆引きマッピングは不要（受信時にaudioURLで引く）
            print("[AlarmAudioCache] Saved cache for eventId=\(eventId)")
        } catch {
            print("[AlarmAudioCache] Failed to save: \(error.localizedDescription)")
        }
    }

    /// audioURLをキーにキャッシュからデータを読み込む
    /// URLのパスからeventIdを推定して検索する
    func load(for audioURLString: String) -> Data? {
        // Firebase Storage URL: .../alarm_audio%2F{eventId}.m4a?...
        // パスからeventIdを抽出
        guard let eventId = extractEventId(from: audioURLString) else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent("\(eventId).m4a")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            print("[AlarmAudioCache] Cache hit for eventId=\(eventId)")
            return data
        } catch {
            print("[AlarmAudioCache] Failed to read cache: \(error.localizedDescription)")
            return nil
        }
    }

    /// キャッシュを削除（古いファイルのクリーンアップ用）
    func remove(eventId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(eventId).m4a")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Firebase Storage URLからeventIdを抽出
    /// URL例: https://firebasestorage.googleapis.com/.../alarm_audio%2F{eventId}.m4a?...
    private func extractEventId(from urlString: String) -> String? {
        // alarm_audio%2F or alarm_audio/ の後ろから .m4a の前まで
        let decoded = urlString.removingPercentEncoding ?? urlString
        guard let range = decoded.range(of: "alarm_audio/") else { return nil }
        let afterPrefix = decoded[range.upperBound...]
        // .m4a? や .m4a の前まで取得
        if let dotRange = afterPrefix.range(of: ".m4a") {
            return String(afterPrefix[..<dotRange.lowerBound])
        }
        return nil
    }
}

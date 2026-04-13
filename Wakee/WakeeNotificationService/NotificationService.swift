import UserNotifications
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.wakee.app.WakeeNotificationService", category: "NSE")

class NotificationService: UNNotificationServiceExtension {

    private static let appGroupID = "group.com.wakee.shared"

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        logger.log("[NSE] didReceive called")
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let type = request.content.userInfo["type"] as? String ?? ""
        let audioURLString = content.userInfo["audioURL"] as? String ?? ""
        logger.log("[NSE] type=\(type), audioURL=\(audioURLString)")

        if type == "alarm_incoming" {
            // audioURLがある場合は録音音声をダウンロードしてCAFに変換し通知サウンドとして再生
            if !audioURLString.isEmpty, let audioURL = URL(string: audioURLString) {
                logger.log("[NSE] Downloading audio for notification sound...")
                Task {
                    do {
                        let (tempURL, _) = try await URLSession.shared.download(from: audioURL)

                        // M4A → CAF (Linear PCM) に変換
                        // UNNotificationSound は WAV/AIFF/CAF のみ対応（M4A/AAC は非対応）
                        let soundFileName = "recorded_alarm.caf"
                        if let soundURL = Self.sharedSoundsURL(fileName: soundFileName) {
                            try FileManager.default.createDirectory(
                                at: soundURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true
                            )
                            if FileManager.default.fileExists(atPath: soundURL.path) {
                                try FileManager.default.removeItem(at: soundURL)
                            }

                            try Self.convertToCAF(from: tempURL, to: soundURL)

                            content.sound = UNNotificationSound(
                                named: UNNotificationSoundName(soundFileName)
                            )
                            logger.log("[NSE] Converted audio set as notification sound")
                        } else {
                            logger.error("[NSE] Failed to get shared sounds directory")
                            content.sound = UNNotificationSound(
                                named: UNNotificationSoundName("alarm_notif.wav")
                            )
                        }
                    } catch {
                        logger.error("[NSE] Audio processing failed: \(error.localizedDescription)")
                        content.sound = UNNotificationSound(
                            named: UNNotificationSoundName("alarm_notif.wav")
                        )
                    }
                    contentHandler(content)
                }
                return
            }

            // audioURLなし → デフォルトアラーム音
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_notif.wav"))
        } else {
            // その他の通知はデフォルトサウンド
            content.sound = .default
        }

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        logger.log("[NSE] serviceExtensionTimeWillExpire")
        if let contentHandler, let bestAttemptContent {
            bestAttemptContent.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_notif.wav"))
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Audio Conversion

    /// M4A/AAC → CAF (Linear PCM 16bit) に変換
    /// UNNotificationSound が再生できる形式に変換する
    private static func convertToCAF(from sourceURL: URL, to destinationURL: URL) throws {
        let inputFile = try AVAudioFile(forReading: sourceURL)
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "NSE", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
        }
        try inputFile.read(into: buffer)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        let outputFile = try AVAudioFile(
            forWriting: destinationURL,
            settings: outputSettings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try outputFile.write(from: buffer)
    }

    // MARK: - Helpers

    /// App Group共有コンテナの Library/Sounds/ 内のファイルURLを返す
    private static func sharedSoundsURL(fileName: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        return containerURL
            .appendingPathComponent("Library/Sounds", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

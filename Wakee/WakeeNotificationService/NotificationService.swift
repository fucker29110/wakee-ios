import UserNotifications
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
            // audioURLがある場合は録音音声をダウンロードして通知サウンドとして再生
            if !audioURLString.isEmpty, let audioURL = URL(string: audioURLString) {
                logger.log("[NSE] Downloading audio for notification sound...")
                Task {
                    do {
                        let (tempURL, _) = try await URLSession.shared.download(from: audioURL)

                        // App Group共有コンテナの Library/Sounds/ に保存
                        // UNNotificationSound はこのディレクトリのファイルを参照できる
                        let soundFileName = "recorded_alarm.m4a"
                        if let soundURL = Self.sharedSoundsURL(fileName: soundFileName) {
                            try FileManager.default.createDirectory(
                                at: soundURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true
                            )
                            // 既存ファイルがあれば削除
                            if FileManager.default.fileExists(atPath: soundURL.path) {
                                try FileManager.default.removeItem(at: soundURL)
                            }
                            try FileManager.default.copyItem(at: tempURL, to: soundURL)

                            content.sound = UNNotificationSound(
                                named: UNNotificationSoundName(soundFileName)
                            )
                            logger.log("[NSE] Recorded audio set as notification sound")
                        } else {
                            logger.error("[NSE] Failed to get shared sounds directory")
                            content.sound = UNNotificationSound(
                                named: UNNotificationSoundName("alarm_notif.wav")
                            )
                        }
                    } catch {
                        logger.error("[NSE] Audio download failed: \(error.localizedDescription)")
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

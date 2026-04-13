import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

@main
struct WakeeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    private static let appGroupID = "group.com.wakee.shared"
    private static let alarmFlagKey = "alarm_incoming_flag"
    private static let alarmUserInfoKey = "alarm_incoming_userInfo"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // URLCache のメモリ上限を制限（AsyncImage等による過剰なキャッシュを防止）
        URLCache.shared.memoryCapacity = 10 * 1024 * 1024  // 10MB
        URLCache.shared.diskCapacity = 50 * 1024 * 1024    // 50MB

        // NSE デバッグログ確認
        if let nseLog = UserDefaults(suiteName: "group.com.wakee.shared")?.string(forKey: "nse_debug_log") {
            print("[NSE Debug] \(nseLog)")
        } else {
            print("[NSE Debug] ログなし（NSE未起動）")
        }

        // Push notification setup
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Darwin notification 監視（Extension からのアラーム通知）
        registerForDarwinNotification()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Notification authorization error: \(error)")
            }
        }
        application.registerForRemoteNotifications()

        // ALARM カテゴリ登録（ロック画面に「起きた！」「スヌーズ」ボタン表示）
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ALARM",
            title: LanguageManager.shared.l("notif_action.woke_up"),
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ALARM",
            title: LanguageManager.shared.l("notif_action.snooze"),
            options: []
        )
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM",
            actions: [dismissAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])

        // 通知タップでアプリ起動された場合をチェック
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            AlarmManager.shared.triggerFromNotification(userInfo: notification)
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - バックグラウンド通知受信（content-available: 1）
    /// ロック画面 / バックグラウンドでプッシュ受信時に Live Activity を起動 + 音声再生
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let type = userInfo["type"] as? String ?? ""
        if type == "alarm_incoming" {
            // 通知音はNSEがUNNotificationSoundで設定済み
            // フォアグラウンド時はRingingScreenのonAppearが音声+バイブを開始する
            AlarmManager.shared.triggerFromNotification(userInfo: userInfo)
            // ローカル通知チェーンで持続的にアラーム音を鳴らす
            // completionHandlerはチェーンのスケジュール完了後に呼ぶ（早期呼び出しでiOSにサスペンドされるのを防止）
            if AlarmManager.shouldTriggerNow(userInfo: userInfo) {
                AlarmManager.shared.scheduleAlarmSoundChain(userInfo: userInfo) {
                    completionHandler(.newData)
                }
            } else {
                completionHandler(.newData)
            }
        } else {
            completionHandler(.noData)
        }
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            try? await AuthService.shared.saveFcmToken(uid: uid, token: fcmToken)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// フォアグラウンドで通知受信 → アラーム通知ならRingingScreen表示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? ""

        if type == "alarm_incoming" {
            // アラーム通知 → RingingScreen表示 + バナーも表示
            AlarmManager.shared.triggerFromNotification(userInfo: userInfo)
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            // その他の通知 → 通常表示
            completionHandler([.banner, .list, .sound, .badge])
        }
    }

    /// 通知アクションボタン / 通知タップ → 種類に応じた処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? ""

        switch type {
        case "alarm_incoming":
            handleAlarmAction(response: response, userInfo: userInfo, completionHandler: completionHandler)
            return // completionHandler は非同期処理完了後に呼ぶ
        case "friend_request":
            // 通知画面でフレンドリクエストを確認
            DeepLinkManager.shared.pendingTab = 0
        case "comment", "repost", "like":
            // ホームタブ → 投稿詳細へ遷移
            DeepLinkManager.shared.pendingTab = 0
            DeepLinkManager.shared.pendingActivityId = userInfo["activityId"] as? String
        case "chat":
            // チャットタブ → 該当チャットルーム
            DeepLinkManager.shared.pendingTab = 3
            DeepLinkManager.shared.pendingChatId = userInfo["chatId"] as? String
        default:
            break
        }
        completionHandler()
    }

    // MARK: - アラーム通知アクション処理

    private func handleAlarmAction(
        response: UNNotificationResponse,
        userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let eventId = userInfo["eventId"] as? String ?? ""
        let senderUid = userInfo["senderUid"] as? String ?? ""
        let senderName = userInfo["senderName"] as? String ?? ""
        let time = userInfo["time"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let snoozeMinStr = userInfo["snoozeMin"] as? String ?? "10"
        let snoozeMin = Int(snoozeMinStr) ?? 10
        let isPrivateStr = userInfo["isPrivate"] as? String ?? "false"
        let isPrivate = isPrivateStr == "true"

        guard let receiverUid = Auth.auth().currentUser?.uid else {
            AlarmSoundService.shared.stop()
            completionHandler()
            return
        }

        switch actionId {
        case "DISMISS_ALARM":
            // 起きた！
            Task {
                await AlarmManager.shared.performDismiss(
                    receiverUid: receiverUid,
                    eventId: eventId,
                    senderUid: senderUid,
                    time: time,
                    message: message,
                    snoozeCount: AlarmManager.shared.currentSnoozeCount,
                    activityType: .achieved,
                    isPrivate: isPrivate
                )
                completionHandler()
            }

        case "SNOOZE_ALARM":
            // スヌーズ
            Task {
                await AlarmManager.shared.performSnooze(
                    receiverUid: receiverUid,
                    eventId: eventId,
                    senderUid: senderUid,
                    senderName: senderName,
                    time: time,
                    message: message,
                    snoozeMin: snoozeMin,
                    snoozeCount: AlarmManager.shared.currentSnoozeCount,
                    isPrivate: isPrivate
                )
                completionHandler()
            }

        case UNNotificationDismissActionIdentifier:
            // スワイプで通知を消去
            AlarmSoundService.shared.stop()
            AlarmManager.shared.cancelAlarmSoundChain()
            completionHandler()

        default:
            // 通知タップ → RingingScreen 表示
            AlarmManager.shared.triggerFromNotification(userInfo: userInfo)
            completionHandler()
        }
    }

    // MARK: - Darwin Notification（Extension → メインアプリ）

    private func registerForDarwinNotification() {
        let name = CFNotificationName("com.wakee.alarm.incoming" as CFString)
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    appDelegate.handleExtensionAlarm()
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func handleExtensionAlarm() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        guard defaults.bool(forKey: Self.alarmFlagKey) else { return }

        // フラグをリセット
        defaults.set(false, forKey: Self.alarmFlagKey)

        if let userInfo = defaults.dictionary(forKey: Self.alarmUserInfoKey) {
            // 通知音はNSEがUNNotificationSoundで設定済み
            AlarmManager.shared.triggerFromNotification(userInfo: userInfo)
            if AlarmManager.shouldTriggerNow(userInfo: userInfo) {
                AlarmManager.shared.scheduleAlarmSoundChain(userInfo: userInfo)
            }
        }
    }
}

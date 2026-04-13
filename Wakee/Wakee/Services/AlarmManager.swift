import Foundation
import FirebaseFirestore
import ActivityKit
import UserNotifications

/**
 * アラーム表示状態を管理するシングルトン
 *
 * 以下の2つのソースからアラームをトリガー:
 * 1. プッシュ通知タップ（AppDelegateから）
 * 2. Firestoreリアルタイム監視（フォアグラウンド時）
 */
@Observable
final class AlarmManager {
    static let shared = AlarmManager()

    // RingingScreen 表示フラグ
    var isRinging = false

    // RingingScreen に渡すパラメータ
    var currentEventId = ""
    var currentSenderName = ""
    var currentSenderUid = ""
    var currentTime = ""
    var currentMessage = ""
    var currentSnoozeMin = 10
    var currentReceiverUid = ""
    var currentSnoozeCount = 0
    var currentAudioURL: String?
    var currentIsPrivate = false

    private var inboxListener: ListenerRegistration?
    private var pendingEvents: [InboxEvent] = []
    private var checkTimer: Timer?
    private var lastTriggeredEventId: String?

    /// 受信者用 Live Activity
    private var receiverActivity: ActivityKit.Activity<WakeeReceiverAlarmAttributes>?

    private init() {}

    // MARK: - プッシュ通知からのトリガー

    /// プッシュ通知のデータからアラームを表示
    /// scheduledAt が未来の場合は鳴らさない（Timerで時刻到達時に鳴動する）
    func triggerFromNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String, type == "alarm_incoming" else { return }
        guard let eventId = userInfo["eventId"] as? String else { return }

        // scheduledAt が未来なら今は鳴らさない → Firestore リスナー + Timer で検出する
        guard Self.shouldTriggerNow(userInfo: userInfo) else { return }

        let senderName = userInfo["senderName"] as? String ?? ""
        let senderUid = userInfo["senderUid"] as? String ?? ""
        let time = userInfo["time"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let snoozeMinStr = userInfo["snoozeMin"] as? String ?? "10"
        let audioURL = userInfo["audioURL"] as? String
        let isPrivateStr = userInfo["isPrivate"] as? String ?? "false"
        let isPrivate = isPrivateStr == "true"

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showRingingScreen(
                eventId: eventId,
                senderName: senderName,
                senderUid: senderUid,
                time: time,
                message: message,
                snoozeMin: Int(snoozeMinStr) ?? 10,
                audioURL: audioURL,
                isPrivate: isPrivate
            )
        }
    }

    // MARK: - Firestore inbox 監視

    /// ログイン後にinboxを監視開始
    func startMonitoring(uid: String) {
        currentReceiverUid = uid
        stopMonitoring()

        inboxListener = AlarmService.shared.subscribeInbox(uid: uid) { [weak self] events in
            guard let self else { return }
            self.pendingEvents = events
            self.checkForDueAlarms()
        }

        // 30秒ごとに再チェック（Firestoreリスナーはドキュメント変更時のみ発火するため、
        // 時刻経過による鳴動はTimerで検出する）
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkForDueAlarms()
        }
    }

    /// 監視停止
    func stopMonitoring() {
        inboxListener?.remove()
        inboxListener = nil
        checkTimer?.invalidate()
        checkTimer = nil
        pendingEvents = []
    }

    /// pending/snoozed イベントのうち scheduledDate を過ぎたものを鳴動
    private func checkForDueAlarms() {
        guard !isRinging else { return }
        let now = Date()
        let dueEvent = pendingEvents.first { event in
            guard event.status == .pending || event.status == .snoozed else { return false }
            guard let scheduled = event.scheduledDate?.dateValue() else { return false }
            // dismiss直後の再トリガー防止
            guard event.id != lastTriggeredEventId else { return false }
            return scheduled <= now
        }

        if let event = dueEvent {
            DispatchQueue.main.async { [weak self] in
                self?.showRingingScreen(
                    eventId: event.id,
                    senderName: event.senderName,
                    senderUid: event.senderUid,
                    time: event.time,
                    message: event.message,
                    snoozeMin: event.snoozeMin,
                    audioURL: event.audioURL,
                    isPrivate: event.isPrivate ?? false
                )
            }
        }
    }

    // MARK: - 画面表示

    private func showRingingScreen(
        eventId: String,
        senderName: String,
        senderUid: String,
        time: String,
        message: String,
        snoozeMin: Int,
        snoozeCount: Int = 0,
        audioURL: String? = nil,
        isPrivate: Bool = false
    ) {
        // 同じイベントの重複トリガーを防止（Push通知パスとDarwin通知パスの同時発火対策）
        if lastTriggeredEventId == eventId && isRinging { return }
        lastTriggeredEventId = eventId

        currentEventId = eventId
        currentSenderName = senderName
        currentSenderUid = senderUid
        currentTime = time
        currentMessage = message
        currentSnoozeMin = snoozeMin
        currentSnoozeCount = snoozeCount
        currentAudioURL = audioURL
        currentIsPrivate = isPrivate
        isRinging = true

        // Live Activity を開始（ロック画面にアラーム表示）
        startReceiverLiveActivity(
            senderName: senderName,
            alarmTime: time,
            message: message
        )
    }

    // MARK: - Live Activity（受信者用）

    /// アラーム受信時に Live Activity を開始
    private func startReceiverLiveActivity(senderName: String, alarmTime: String, message: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 既存のアクティビティがあれば終了
        endReceiverLiveActivity()

        let attributes = WakeeReceiverAlarmAttributes(
            senderName: senderName,
            alarmTime: alarmTime,
            message: message
        )
        let initialState = WakeeReceiverAlarmAttributes.ContentState(
            state: .ringing,
            snoozeCount: 0
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            receiverActivity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[AlarmManager] Live Activity started")
        } catch {
            print("[AlarmManager] Live Activity start error: \(error)")
        }
    }

    /// スヌーズ時に Live Activity を更新
    func updateLiveActivitySnoozed(snoozeCount: Int) {
        guard let activity = receiverActivity else { return }
        let newState = WakeeReceiverAlarmAttributes.ContentState(
            state: .snoozed,
            snoozeCount: snoozeCount
        )
        let content = ActivityContent(state: newState, staleDate: nil)
        Task { await activity.update(content) }
    }

    /// アラーム停止時に Live Activity を終了
    func endReceiverLiveActivity() {
        guard let activity = receiverActivity else { return }
        let finalState = WakeeReceiverAlarmAttributes.ContentState(
            state: .dismissed,
            snoozeCount: currentSnoozeCount
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        Task {
            await activity.end(finalContent, dismissalPolicy: .default)
        }
        receiverActivity = nil
        print("[AlarmManager] Live Activity ended")
    }

    /// RingingScreen が閉じられた時に呼ぶ
    func dismiss() {
        isRinging = false
        cancelAlarmSoundChain()
        // lastTriggeredEventId はスヌーズ後の再トリガーを許可するためにクリアしない
        // Firestore側で status が dismissed になれば checkForDueAlarms のフィルタで除外される
        endReceiverLiveActivity()
    }

    // MARK: - 共通アクション（通知アクション / RingingScreen 両方から呼ばれる）

    /// 「起きた！」処理
    func performDismiss(
        receiverUid: String,
        eventId: String,
        senderUid: String,
        time: String,
        message: String,
        snoozeCount: Int,
        activityType: ActivityType,
        audioURL: String? = nil,
        isPrivate: Bool = false
    ) async {
        AlarmSoundService.shared.stop()

        try? await AlarmService.shared.updateInboxStatus(
            receiverUid: receiverUid,
            eventId: eventId,
            status: .dismissed
        )

        let friendUids = try? await FriendService.shared.getFriendUids(uid: receiverUid)
        let visibleTo = Array(Set([receiverUid, senderUid] + (friendUids ?? [])))

        try? await ActivityService.shared.record(
            type: activityType,
            actorUid: receiverUid,
            targetUid: senderUid,
            relatedEventId: eventId,
            time: time,
            message: message,
            audioURL: audioURL,
            snoozeCount: snoozeCount,
            displayMessage: nil,
            visibleTo: visibleTo,
            isPrivate: isPrivate
        )

        await MainActor.run {
            endReceiverLiveActivity()
            dismiss()
        }
    }

    /// スヌーズ処理
    func performSnooze(
        receiverUid: String,
        eventId: String,
        senderUid: String,
        senderName: String,
        time: String,
        message: String,
        snoozeMin: Int,
        snoozeCount: Int,
        isPrivate: Bool = false
    ) async {
        AlarmSoundService.shared.stop()

        let event = InboxEvent(
            docID: eventId,
            senderUid: senderUid,
            senderName: senderName,
            time: time,
            label: "",
            message: message,
            repeat: [],
            snoozeMin: snoozeMin,
            status: .snoozed
        )
        try? await AlarmService.shared.snoozeAlarm(
            receiverUid: receiverUid,
            event: event,
            snoozeMin: snoozeMin
        )

        let friendUids = try? await FriendService.shared.getFriendUids(uid: receiverUid)
        let visibleTo = Array(Set([receiverUid, senderUid] + (friendUids ?? [])))

        try? await ActivityService.shared.record(
            type: .snoozed,
            actorUid: receiverUid,
            targetUid: senderUid,
            relatedEventId: eventId,
            time: time,
            snoozeCount: snoozeCount + 1,
            displayMessage: LanguageManager.shared.l("service.snooze_message", args: snoozeCount + 1),
            visibleTo: visibleTo,
            isPrivate: isPrivate
        )

        await MainActor.run {
            updateLiveActivitySnoozed(snoozeCount: snoozeCount + 1)
            // スヌーズ後に同じイベントが再トリガーできるよう lastTriggeredEventId をクリア
            lastTriggeredEventId = nil
            dismiss()
        }
    }

    // MARK: - Alarm Sound Chain（ローカル通知による持続的アラーム音）

    /// プッシュ受信時にローカル通知を30秒間隔でスケジュールし、持続的にアラーム音を鳴らす
    /// completion はすべての通知がスケジュール完了した後に呼ばれる
    func scheduleAlarmSoundChain(userInfo: [AnyHashable: Any], completion: (() -> Void)? = nil) {
        cancelAlarmSoundChain()

        let senderName = userInfo["senderName"] as? String ?? ""
        let message = userInfo["message"] as? String ?? ""
        let time = userInfo["time"] as? String ?? ""
        let lang = LanguageManager.shared

        // 元のuserInfoからチェーン通知用のuserInfoを構築
        var chainUserInfo: [String: String] = [
            "type": "alarm_incoming",
            "eventId": userInfo["eventId"] as? String ?? "",
            "senderName": senderName,
            "senderUid": userInfo["senderUid"] as? String ?? "",
            "time": time,
            "message": message,
            "snoozeMin": userInfo["snoozeMin"] as? String ?? "10",
            "isPrivate": userInfo["isPrivate"] as? String ?? "false",
        ]
        if let audioURL = userInfo["audioURL"] as? String {
            chainUserInfo["audioURL"] = audioURL
        }

        let center = UNUserNotificationCenter.current()
        // 元のプッシュ通知を配信済みリストから削除して音声抑制を回避
        center.removeAllDeliveredNotifications()

        let group = DispatchGroup()
        for i in 1...10 {
            let content = UNMutableNotificationContent()
            content.title = lang.l("service.alarm_from", args: senderName)
            content.body = message.isEmpty
                ? "\(time) - " + lang.l("ringing.alarm_arrived")
                : "\(time) - \(message)"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_notif.wav"))
            content.categoryIdentifier = "ALARM"
            content.interruptionLevel = .timeSensitive
            content.userInfo = chainUserInfo
            // 各チェーン通知を別スレッドにしてiOSのグループ化・音声抑制を回避
            content.threadIdentifier = "alarm_chain_\(i)"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(30 * i), repeats: false)
            let request = UNNotificationRequest(
                identifier: "alarm_chain_\(i)", content: content, trigger: trigger)
            group.enter()
            center.add(request) { error in
                if let error {
                    print("[AlarmChain] Failed to schedule \(i): \(error)")
                } else {
                    print("[AlarmChain] Scheduled chain \(i) at \(30 * i)s")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            print("[AlarmChain] All \(10) notifications scheduled")
            completion?()
        }
    }

    /// アラーム停止時にチェーン通知をキャンセル
    func cancelAlarmSoundChain() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (1...10).map { "alarm_chain_\($0)" })
    }

    // MARK: - scheduledAt チェック共通ヘルパー

    /// userInfo の scheduledAt を確認し、今トリガーすべきかどうかを返す
    static func shouldTriggerNow(userInfo: [AnyHashable: Any]) -> Bool {
        guard let scheduledAtStr = userInfo["scheduledAt"] as? String,
              let scheduledAtMs = Double(scheduledAtStr) else { return true }
        let scheduledDate = Date(timeIntervalSince1970: scheduledAtMs / 1000)
        return scheduledDate <= Date().addingTimeInterval(60)
    }
}

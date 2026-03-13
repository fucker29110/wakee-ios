import ActivityKit
import FirebaseFirestore
import Foundation

/// Live Activity のライフサイクル管理
/// 送信者がアラームを送ると開始し、受信者のステータス変化をリアルタイムに反映する
@Observable
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    /// ActivityKit.Activity を明示（プロジェクト内の Models/Activity と名前衝突を回避）
    private var currentActivity: ActivityKit.Activity<WakeeAlarmAttributes>?

    /// 現在のレシーバー状態（Firestoreリスナーが更新）
    private var receiverStates: [WakeeAlarmAttributes.ReceiverState] = []

    /// 受信者ごとの ringing タイムアウト（2分で ignored に変更）
    private var ringingTimeoutTasks: [String: Task<Void, Never>] = [:]

    /// タイムアウトで ignored に更新するための eventId を保持
    private var eventIdsByUid: [String: String] = [:]

    // MARK: - Start

    /// アラーム送信後に Live Activity を開始
    /// - Parameters:
    ///   - alarmTime: アラーム時刻（"07:00" 形式）
    ///   - senderUsername: 送信者のユーザー名
    ///   - receivers: 受信者リスト（uid, username）
    ///   - eventIds: 受信者uidに対応するinbox eventId辞書
    func startActivity(
        alarmTime: String,
        senderUsername: String,
        receivers: [(uid: String, username: String)],
        eventIds: [String: String]
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled")
            return
        }

        // 全員 pending で初期化
        receiverStates = receivers.map { r in
            WakeeAlarmAttributes.ReceiverState(
                uid: r.uid,
                username: r.username,
                status: .pending,
                snoozeCount: 0
            )
        }

        let attributes = WakeeAlarmAttributes(
            alarmTime: alarmTime,
            senderUsername: senderUsername
        )
        let initialState = WakeeAlarmAttributes.ContentState(
            receivers: receiverStates
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")

            // eventId マップを保持（タイムアウト時の Firestore 更新用）
            eventIdsByUid = eventIds

            // 各受信者の inbox を監視
            startListeners(eventIds: eventIds)
        } catch {
            print("[LiveActivity] Start error: \(error)")
        }
    }

    // MARK: - Listeners

    /// 各受信者の inbox ドキュメントを個別に監視
    private func startListeners(eventIds: [String: String]) {
        stopListeners()

        for (receiverUid, eventId) in eventIds {
            let listener = db.collection("users").document(receiverUid)
                .collection("inbox").document(eventId)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        print("[LiveActivity] Listener error for \(receiverUid): \(error)")
                        return
                    }
                    guard let self, let data = snapshot?.data() else {
                        print("[LiveActivity] No data for \(receiverUid)")
                        return
                    }
                    let statusRaw = data["status"] as? String ?? "pending"
                    print("[LiveActivity] \(receiverUid) status: \(statusRaw)")
                    let inboxStatus = InboxStatus(rawValue: statusRaw) ?? .pending

                    let receiverStatus = self.mapStatus(inboxStatus)
                    self.updateReceiverStatus(uid: receiverUid, status: receiverStatus)
                }
            listeners.append(listener)
        }
    }

    /// InboxStatus → ReceiverStatus マッピング
    private func mapStatus(_ inbox: InboxStatus) -> WakeeAlarmAttributes.ReceiverStatus {
        switch inbox {
        case .pending:   return .pending
        case .scheduled: return .pending
        case .rung:      return .ringing
        case .dismissed: return .achieved
        case .snoozed:   return .snoozed
        case .ignored:   return .ignored
        }
    }

    /// 特定レシーバーのステータスを更新し、Live Activity を反映
    private func updateReceiverStatus(uid: String, status: WakeeAlarmAttributes.ReceiverStatus) {
        guard let idx = receiverStates.firstIndex(where: { $0.uid == uid }) else { return }

        // スヌーズカウント
        var updated = receiverStates[idx]
        if status == .snoozed {
            updated = WakeeAlarmAttributes.ReceiverState(
                uid: updated.uid,
                username: updated.username,
                status: .snoozed,
                snoozeCount: updated.snoozeCount + 1
            )
        } else {
            updated = WakeeAlarmAttributes.ReceiverState(
                uid: updated.uid,
                username: updated.username,
                status: status,
                snoozeCount: updated.snoozeCount
            )
        }
        receiverStates[idx] = updated

        // ringing タイムアウト管理
        manageRingingTimeout(uid: uid, status: status)

        // Live Activity 更新
        let newState = WakeeAlarmAttributes.ContentState(receivers: receiverStates)
        let newContent = ActivityContent(state: newState, staleDate: nil)
        Task { await currentActivity?.update(newContent) }

        // 全員確定したら終了
        checkAndEndIfAllFinalized()
    }

    // MARK: - Ringing Timeout

    /// ringing になったら2分タイマー開始、achieved/snoozed が来たらキャンセル
    private func manageRingingTimeout(uid: String, status: WakeeAlarmAttributes.ReceiverStatus) {
        switch status {
        case .ringing:
            // 既にタイマーが走っていれば何もしない（スヌーズ→再ringing のケース）
            guard ringingTimeoutTasks[uid] == nil else { return }
            ringingTimeoutTasks[uid] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled, let self else { return }
                await self.markAsIgnored(uid: uid)
            }
        case .achieved, .snoozed, .ignored:
            // 確定 or スヌーズが来たらタイマーをキャンセル
            ringingTimeoutTasks[uid]?.cancel()
            ringingTimeoutTasks[uid] = nil
        case .pending:
            break
        }
    }

    /// Firestore の status を ignored に更新し、ローカル状態も反映
    @MainActor
    private func markAsIgnored(uid: String) {
        // 既に確定済みなら何もしない
        if let idx = receiverStates.firstIndex(where: { $0.uid == uid }),
           receiverStates[idx].status.isFinalized {
            return
        }

        // Firestore 更新
        if let eventId = eventIdsByUid[uid] {
            db.collection("users").document(uid)
                .collection("inbox").document(eventId)
                .updateData(["status": "ignored"])
        }
        // Firestore リスナーが ignored を検知して updateReceiverStatus が呼ばれるため
        // ローカル状態の直接更新は不要
    }

    // MARK: - End

    /// 全受信者が確定ステータスなら Live Activity を終了
    private func checkAndEndIfAllFinalized() {
        let allFinalized = receiverStates.allSatisfy { $0.status.isFinalized }
        guard allFinalized else { return }

        // 3秒後に終了（結果を見る時間を確保）
        Task {
            try? await Task.sleep(for: .seconds(3))
            await endActivity()
        }
    }

    /// Live Activity を終了
    @MainActor
    func endActivity() {
        guard let activity = currentActivity else { return }
        let finalState = WakeeAlarmAttributes.ContentState(receivers: receiverStates)
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        Task {
            await activity.end(finalContent, dismissalPolicy: .default)
        }
        stopListeners()
        cancelAllTimeouts()
        currentActivity = nil
        receiverStates = []
        eventIdsByUid = [:]
        print("[LiveActivity] Ended")
    }

    /// リスナー停止
    private func stopListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    /// 全タイムアウトタスクをキャンセル
    private func cancelAllTimeouts() {
        ringingTimeoutTasks.values.forEach { $0.cancel() }
        ringingTimeoutTasks.removeAll()
    }
}

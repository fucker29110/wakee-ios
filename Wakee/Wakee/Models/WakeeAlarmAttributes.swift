import ActivityKit
import Foundation

/// Live Activity で使用するアラーム状態の定義
/// メインアプリと Widget Extension の両方から参照する
struct WakeeAlarmAttributes: ActivityAttributes {

    /// 受信者ごとの起床ステータス
    enum ReceiverStatus: String, Codable {
        case pending    // アラーム送信済み、まだ鳴っていない
        case ringing    // アラーム鳴動中
        case achieved   // 起きた！
        case snoozed    // スヌーズ中
        case ignored    // 無視した / 起きなかった
    }

    /// 受信者1人分の状態
    struct ReceiverState: Codable, Hashable {
        let uid: String
        let username: String
        var status: ReceiverStatus
        var snoozeCount: Int
    }

    /// 動的に変化する状態（ContentState）
    struct ContentState: Codable, Hashable {
        var receivers: [ReceiverState]
    }

    // MARK: - 固定属性（Activity開始時に設定、変更不可）

    /// アラーム時刻（"07:00" 形式）
    let alarmTime: String

    /// 送信者のユーザーID
    let senderUsername: String
}

// MARK: - ステータス絵文字ヘルパー

extension WakeeAlarmAttributes.ReceiverStatus {
    var emoji: String {
        switch self {
        case .pending:  return ""
        case .ringing:  return "\u{23F0}"
        case .achieved: return "\u{2705}"
        case .snoozed:  return "\u{1F634}"
        case .ignored:  return "\u{274C}"
        }
    }

    var label: String {
        switch self {
        case .pending:  return String(localized: "live.pending")
        case .ringing:  return String(localized: "live.ringing")
        case .achieved: return String(localized: "live.achieved")
        case .snoozed:  return String(localized: "live.snoozed")
        case .ignored:  return String(localized: "live.ignored")
        }
    }

    /// 結果が確定したか（更新が完了したステータス）
    var isFinalized: Bool {
        self == .achieved || self == .ignored
    }
}

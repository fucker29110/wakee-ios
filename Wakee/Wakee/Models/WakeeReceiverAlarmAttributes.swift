import ActivityKit
import Foundation

/// 受信者側のアラーム Live Activity で使用する属性
struct WakeeReceiverAlarmAttributes: ActivityAttributes {

    /// アラームの現在のステータス
    enum AlarmState: String, Codable {
        case ringing     // アラーム鳴動中
        case snoozed     // スヌーズ中
        case dismissed   // 停止済み
    }

    /// 動的に変化する状態
    struct ContentState: Codable, Hashable {
        var state: AlarmState
        var snoozeCount: Int
    }

    // MARK: - 固定属性（Activity開始時に設定）

    /// 送信者の名前
    let senderName: String

    /// アラーム時刻（"07:00" 形式）
    let alarmTime: String

    /// メッセージ
    let message: String
}

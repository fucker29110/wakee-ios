import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity の UI 定義
/// ロック画面 + Dynamic Island に送信したアラームの結果をリアルタイム表示
struct WakeeAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WakeeAlarmAttributes.self) { context in
            // MARK: - ロック画面 UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded（長押し展開時）
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(Color(hex: "#FF6B35"))
                        Text(context.attributes.alarmTime)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    let achieved = context.state.receivers.filter { $0.status == .achieved }.count
                    let total = context.state.receivers.count
                    Text("\(achieved)/\(total) ✅")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#22C55E"))
                }

                DynamicIslandExpandedRegion(.center) {
                    // 何も表示しない（bottom で全員の状態を一覧表示）
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // 受信者一覧 + ステータス
                    VStack(spacing: 6) {
                        ForEach(context.state.receivers, id: \.uid) { receiver in
                            HStack {
                                Text(receiver.username)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Spacer()

                                Text(statusText(receiver))
                                    .font(.system(size: 13))
                                    .foregroundColor(statusColor(receiver.status))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // MARK: - Compact Leading（左側）
                Image(systemName: "alarm.fill")
                    .foregroundColor(Color(hex: "#FF6B35"))
            } compactTrailing: {
                // MARK: - Compact Trailing（右側）
                let achieved = context.state.receivers.filter { $0.status == .achieved }.count
                let total = context.state.receivers.count
                Text("\(achieved)/\(total) ✅")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#22C55E"))
            } minimal: {
                // MARK: - Minimal（アイコンのみ）
                Image(systemName: "alarm.fill")
                    .foregroundColor(Color(hex: "#FF6B35"))
            }
        }
    }

    // MARK: - ロック画面ビュー

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WakeeAlarmAttributes>) -> some View {
        let receivers = context.state.receivers
        let total = receivers.count
        let achieved = receivers.filter { $0.status == .achieved }.count

        VStack(spacing: 8) {
            // ヘッダー: 時刻 + 概要
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(Color(hex: "#FF6B35"))
                    Text(context.attributes.alarmTime)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // ステータスアイコン列
                HStack(spacing: 2) {
                    ForEach(receivers, id: \.uid) { r in
                        Text(r.status.emoji)
                            .font(.system(size: 14))
                    }
                }
            }

            // 概要テキスト
            HStack {
                if total == 1, let r = receivers.first {
                    // 1人の場合: @名前 + ステータス
                    Text("@\(r.username) \(lockScreenStatusText(r))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor(r.status))
                } else {
                    // 複数人の場合: カウント
                    Text("\(achieved)/\(total)人が起きた")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()
            }

            // 複数人の場合: 各受信者の状態を一覧
            if total > 1 {
                VStack(spacing: 4) {
                    ForEach(receivers, id: \.uid) { receiver in
                        HStack {
                            Text(receiver.status.emoji)
                                .font(.system(size: 12))
                            Text("@\(receiver.username)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text(statusText(receiver))
                                .font(.system(size: 12))
                                .foregroundColor(statusColor(receiver.status))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - ヘルパー

    private func statusText(_ receiver: WakeeAlarmAttributes.ReceiverState) -> String {
        switch receiver.status {
        case .pending:  return "待機中..."
        case .ringing:  return "アラーム鳴動中..."
        case .achieved: return "起きた！"
        case .snoozed:
            let suffix = receiver.snoozeCount > 0 ? " (\(receiver.snoozeCount)回目)" : ""
            return "スヌーズ中\(suffix)"
        case .ignored:  return "起きなかった..."
        }
    }

    private func lockScreenStatusText(_ receiver: WakeeAlarmAttributes.ReceiverState) -> String {
        switch receiver.status {
        case .pending:  return "が起きるのを待っています"
        case .ringing:  return "のアラームが鳴っています"
        case .achieved: return "が起きた！"
        case .snoozed:
            let suffix = receiver.snoozeCount > 0 ? " (\(receiver.snoozeCount)回目)" : ""
            return "がスヌーズ中\(suffix)"
        case .ignored:  return "は起きなかった..."
        }
    }

    private func statusColor(_ status: WakeeAlarmAttributes.ReceiverStatus) -> Color {
        switch status {
        case .pending:  return Color(hex: "#9CA3AF")
        case .ringing:  return Color(hex: "#FF6B35")
        case .achieved: return Color(hex: "#22C55E")
        case .snoozed:  return Color(hex: "#FBBF24")
        case .ignored:  return Color(hex: "#EF4444")
        }
    }
}

// MARK: - Color hex extension (Widget用)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

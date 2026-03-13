import ActivityKit
import WidgetKit
import SwiftUI

/// 受信者側のアラーム Live Activity UI
/// ロック画面 + Dynamic Island にアラーム受信状態を表示		    	
struct WakeeReceiverAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WakeeReceiverAlarmAttributes.self) { context in
            // MARK: - ロック画面 UI
            receiverLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(accentColor)
                        Text(context.attributes.alarmTime)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(stateEmoji(context.state.state))
                        .font(.system(size: 20))
                }

                DynamicIslandExpandedRegion(.center) {}

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text("\(context.attributes.senderName) からのアラーム")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text(stateLabel(context.state))
                            .font(.system(size: 13))
                            .foregroundColor(stateColor(context.state.state))

                        if !context.attributes.message.isEmpty {
                            Text(context.attributes.message)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundColor(accentColor)
            } compactTrailing: {
                Text(stateEmoji(context.state.state))
                    .font(.system(size: 14))
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundColor(accentColor)
            }
        }
    }

    // MARK: - ロック画面ビュー

    @ViewBuilder
    private func receiverLockScreenView(context: ActivityViewContext<WakeeReceiverAlarmAttributes>) -> some View {
        VStack(spacing: 10) {
            // ヘッダー
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accentColor)
                    Text(context.attributes.alarmTime)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(stateEmoji(context.state.state))
                    .font(.system(size: 24))
            }

            // 送信者名
            HStack {
                Text("\(context.attributes.senderName) からのアラーム")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            // ステータス
            HStack {
                Text(stateLabel(context.state))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(stateColor(context.state.state))

                Spacer()
            }

            // メッセージ
            if !context.attributes.message.isEmpty {
                HStack {
                    Text(context.attributes.message)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - ヘルパー

    private var accentColor: Color { Color(hex: "#FF6B35") }

    private func stateEmoji(_ state: WakeeReceiverAlarmAttributes.AlarmState) -> String {
        switch state {
        case .ringing:   return "⏰"
        case .snoozed:   return "😴"
        case .dismissed: return "✅"
        }
    }

    private func stateLabel(_ state: WakeeReceiverAlarmAttributes.ContentState) -> String {
        switch state.state {
        case .ringing:   return "アラーム鳴動中！タップして停止"
        case .snoozed:   return "スヌーズ中 (\(state.snoozeCount)回目)"
        case .dismissed: return "起きた！"
        }
    }

    private func stateColor(_ state: WakeeReceiverAlarmAttributes.AlarmState) -> Color {
        switch state {
        case .ringing:   return Color(hex: "#FF6B35")
        case .snoozed:   return Color(hex: "#FBBF24")
        case .dismissed: return Color(hex: "#22C55E")
        }
    }
}

// MARK: - Color hex extension

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

import SwiftUI

struct RingingScreen: View {
    let eventId: String
    let senderName: String
    let senderUid: String
    let time: String
    let message: String
    let snoozeMin: Int
    let receiverUid: String
    var snoozeCount: Int = 0
    var audioURL: String?

    @Environment(\.dismiss) private var dismiss
    @State private var isActing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var startTime = Date()

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()

                // Pulse animation
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale * 0.9)

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.accent)
                }

                // Info
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(senderName)
                        .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)

                    Text(TimeUtils.formatAlarmTime(time))
                        .font(.system(size: AppTheme.FontSize.xxl, weight: .extrabold))
                        .foregroundStyle(AppTheme.accentGradient)

                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: AppTheme.FontSize.md))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }

                    if snoozeCount > 0 {
                        Text("スヌーズ \(snoozeCount)回目")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: AppTheme.Spacing.md) {
                    // Dismiss button
                    Button(action: handleDismiss) {
                        Text("起きた！")
                            .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.accentGradient)
                            )
                    }
                    .disabled(isActing)

                    // Snooze button
                    Button(action: handleSnooze) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "clock.fill")
                            Text("スヌーズ (\(snoozeMin)分)")
                        }
                        .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(isActing)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            AlarmSoundService.shared.play(audioURL: audioURL)
            startPulseAnimation()
        }
        .onDisappear {
            AlarmSoundService.shared.stop()
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    private func handleDismiss() {
        guard !isActing else { return }
        isActing = true
        AlarmSoundService.shared.stop()

        let elapsed = Date().timeIntervalSince(startTime)
        let activityType: ActivityType = elapsed < 30 ? .achieved : .rejected

        Task {
            try? await AlarmService.shared.updateInboxStatus(
                receiverUid: receiverUid,
                eventId: eventId,
                status: .dismissed
            )

            let friendUids = try? await FriendService.shared.getFriendUids(uid: receiverUid)
            let visibleTo = Array(Set([receiverUid, senderUid] + (friendUids ?? [])))

            let messages = activityType == .achieved
                ? ["目覚めスッキリ！", "おはよう！", "今日も頑張ろう！"]
                : ["あと5分...", "もう少しだけ...", "眠い..."]
            let displayMsg = messages.randomElement()

            try? await ActivityService.shared.record(
                type: activityType,
                actorUid: receiverUid,
                targetUid: senderUid,
                relatedEventId: eventId,
                time: time,
                message: message,
                snoozeCount: snoozeCount,
                displayMessage: displayMsg,
                visibleTo: visibleTo
            )

            await MainActor.run { dismiss() }
        }
    }

    private func handleSnooze() {
        guard !isActing else { return }
        isActing = true
        AlarmSoundService.shared.stop()

        Task {
            let event = InboxEvent(
                docID: eventId,
                senderUid: senderUid,
                senderName: senderName,
                time: time,
                label: "",
                message: message,
                repeat: [],
                snoozeMin: snoozeMin,
                status: .snoozed,
                audioURL: audioURL
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
                displayMessage: "スヌーズ \(snoozeCount + 1)回目",
                visibleTo: visibleTo
            )

            await MainActor.run { dismiss() }
        }
    }
}

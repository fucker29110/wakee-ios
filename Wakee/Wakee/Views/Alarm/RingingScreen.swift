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
    var isPrivate: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var isActing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var startTime = Date()
    @State private var senderPhotoURL: String?
    @State private var senderUsername: String?
    @Environment(LanguageManager.self) private var lang

    private var displayTime: String {
        TimeUtils.formatAlarmTime(time)
    }

    var body: some View {
        ZStack {
            // グラデーション背景
            LinearGradient(
                colors: [
                    Color(hex: "#0d0d0d"),
                    Color(hex: "#1a0d06"),
                    Color(hex: "#0d0d0d")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // アバター（パルスアニメーション付き）
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulseScale * 0.95)

                    AvatarView(name: senderName, photoURL: senderPhotoURL, size: 100)
                }

                Spacer().frame(height: 24)

                // @username から アラームが届きました
                HStack(spacing: 4) {
                    Text("@\(senderUsername ?? senderName)")
                        .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accent)
                    Text(lang.l("ringing.from"))
                        .font(.system(size: AppTheme.FontSize.md))
                        .foregroundColor(AppTheme.Colors.secondary)
                }

                Spacer().frame(height: 8)

                Text(lang.l("ringing.alarm_arrived"))
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.secondary)

                // 区切り線
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 1)
                    .padding(.vertical, 20)

                // 時刻
                Text(displayTime)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                // スヌーズ回数
                if snoozeCount > 0 {
                    Text(lang.l("ringing.snooze_count", args: snoozeCount))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.top, 8)
                }

                // メッセージバブル
                if !message.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.l("ringing.message"))
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)

                        Text(message)
                            .font(.system(size: AppTheme.FontSize.md))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.top, 24)
                }

                Spacer()

                // アクションボタン
                VStack(spacing: AppTheme.Spacing.sm) {
                    // 起きた！ボタン
                    Button(action: handleDismiss) {
                        Text(lang.l("ringing.woke_up"))
                            .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.accentGradient)
                                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, y: 4)
                            )
                    }
                    .disabled(isActing)

                    // スヌーズボタン
                    Button(action: handleSnooze) {
                        Text(lang.l("ringing.snooze", args: snoozeMin))
                            .font(.system(size: AppTheme.FontSize.md, weight: .medium))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .disabled(isActing)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, 50)
            }
        }
        .statusBarHidden()
        .onAppear {
            AlarmSoundService.shared.play(audioURL: audioURL)
            startPulseAnimation()
            loadSenderInfo()
        }
        .onDisappear {
            AlarmSoundService.shared.stop()
        }
    }

    // MARK: - 送信者情報を取得

    private func loadSenderInfo() {
        Task {
            let infos = await ActivityService.shared.getUserInfoByUids([senderUid])
            if let info = infos[senderUid] {
                await MainActor.run {
                    senderPhotoURL = info.photoURL
                    senderUsername = info.username
                }
            }
        }
    }

    // MARK: - アニメーション

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    // MARK: - 起きた！

    private func handleDismiss() {
        guard !isActing else { return }
        isActing = true

        let elapsed = Date().timeIntervalSince(startTime)
        let activityType: ActivityType = elapsed < 30 ? .achieved : .rejected

        Task {
            await AlarmManager.shared.performDismiss(
                receiverUid: receiverUid,
                eventId: eventId,
                senderUid: senderUid,
                time: time,
                message: message,
                snoozeCount: snoozeCount,
                activityType: activityType,
                audioURL: audioURL,
                isPrivate: isPrivate
            )
            await MainActor.run { dismiss() }
        }
    }

    // MARK: - スヌーズ

    private func handleSnooze() {
        guard !isActing else { return }
        isActing = true

        Task {
            await AlarmManager.shared.performSnooze(
                receiverUid: receiverUid,
                eventId: eventId,
                senderUid: senderUid,
                senderName: senderName,
                time: time,
                message: message,
                snoozeMin: snoozeMin,
                snoozeCount: snoozeCount,
                isPrivate: isPrivate
            )
            await MainActor.run { dismiss() }
        }
    }
}

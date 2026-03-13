import SwiftUI

struct ProfileScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var profileVM = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                if let user = authVM.user {
                    // Profile card
                    VStack(spacing: AppTheme.Spacing.md) {
                        AvatarView(name: user.displayName, photoURL: user.photoURL, size: 80)

                        Text(user.displayName)
                            .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text("@\(user.username)")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.primary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Stats
                    HStack(spacing: AppTheme.Spacing.xl) {
                        statItem(value: "\(profileVM.friendCount)", label: "フレンド")
                        statItem(value: "\(profileVM.sentCount)", label: "送信")
                        statItem(value: "\(profileVM.achievedCount)", label: "達成")
                        statItem(value: "\(user.streak)", label: "ストリーク")
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.BorderRadius.md)

                    // Actions
                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink {
                            ProfileEditScreen()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("プロフィール編集")
                            }
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            )
                        }

                        NavigationLink {
                            SettingsScreen()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                Text("設定")
                            }
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Activity history
                    if !profileVM.activities.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("アクティビティ履歴")
                                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)

                            ForEach(profileVM.activities.prefix(20)) { activity in
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: activityIcon(activity.type))
                                        .foregroundColor(AppTheme.Colors.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activityLabel(activity.type))
                                            .font(.system(size: AppTheme.FontSize.sm))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        if let msg = activity.displayMessage ?? activity.message, !msg.isEmpty {
                                            Text(msg)
                                                .font(.system(size: AppTheme.FontSize.xs))
                                                .foregroundColor(AppTheme.Colors.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text(TimeUtils.timeAgo(from: activity.createdDate))
                                        .font(.system(size: AppTheme.FontSize.xs))
                                        .foregroundColor(AppTheme.Colors.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.BorderRadius.md)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            profileVM.subscribe(uid: uid)
        }
        .onDisappear { profileVM.unsubscribe() }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                .foregroundColor(AppTheme.Colors.accent)
            Text(label)
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func activityIcon(_ type: ActivityType) -> String {
        switch type {
        case .achieved: return "sun.max.fill"
        case .rejected: return "moon.zzz.fill"
        case .snoozed: return "clock.fill"
        case .sent: return "alarm.fill"
        case .received_wakeup: return "bell.fill"
        case .repost: return "arrow.2.squarepath"
        }
    }

    private func activityLabel(_ type: ActivityType) -> String {
        switch type {
        case .achieved: return "起きた!"
        case .rejected: return "二度寝した..."
        case .snoozed: return "スヌーズした"
        case .sent: return "アラームを送った"
        case .received_wakeup: return "アラームを受け取った"
        case .repost: return "リポストした"
        }
    }
}

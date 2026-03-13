import SwiftUI

struct FeedItemView: View {
    let activity: Activity
    let userMap: [String: ActivityService.UserInfo]
    let activityLabel: String
    let activityIcon: String

    private var actorName: String {
        userMap[activity.actorUid]?.displayName ?? "ユーザー"
    }

    private var actorPhotoURL: String? {
        userMap[activity.actorUid]?.photoURL
    }

    private var targetName: String? {
        activity.targetUid.flatMap { userMap[$0]?.displayName }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AvatarView(name: actorName, photoURL: actorPhotoURL, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(actorName)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                    Text(activityLabel)
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .font(.system(size: AppTheme.FontSize.sm))

                if let targetName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                        Text(targetName)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: activityIcon)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.accent)
                        Text(TimeUtils.formatAlarmTime(activity.time))
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }

                    Text(TimeUtils.timeAgo(from: activity.createdDate))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)

                    if let count = activity.commentCount, count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 10))
                            Text("\(count)")
                                .font(.system(size: AppTheme.FontSize.xs))
                        }
                        .foregroundColor(AppTheme.Colors.secondary)
                    }
                }

                if let message = activity.displayMessage ?? activity.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.primary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }

                // Repost card
                if activity.type == .repost, activity.repostComment != nil {
                    Text(activity.repostComment!)
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .italic()
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#1F1F1F"))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

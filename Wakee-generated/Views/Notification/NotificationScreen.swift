import SwiftUI

struct NotificationScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var notifVM = NotificationViewModel()

    var body: some View {
        Group {
            if notifVM.isLoading {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifVM.notifications.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text("通知はまだありません")
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(notifVM.notifications) { notif in
                    notificationRow(notif)
                        .listRowBackground(notif.read ? AppTheme.Colors.background : AppTheme.Colors.surface)
                        .listRowSeparatorTint(Color(hex: "#1F1F1F"))
                }
                .listStyle(.plain)
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if notifVM.unreadCount > 0 {
                ToolbarItem(placement: .topBarRight) {
                    Button("既読にする") {
                        guard let uid = authVM.user?.uid else { return }
                        notifVM.markAllAsRead(uid: uid)
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.system(size: AppTheme.FontSize.sm))
                }
            }
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            notifVM.subscribe(uid: uid)
        }
        .onDisappear { notifVM.unsubscribe() }
    }

    private func notificationRow(_ notif: AppNotification) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: notif.senderName, photoURL: nil, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .fontWeight(.semibold)
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.primary)
                Text(notif.body)
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .lineLimit(2)
                Text(TimeUtils.timeAgo(from: notif.createdDate))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }

            Spacer()

            if !notif.read {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private func notificationIcon(_ type: NotificationType) -> String {
        switch type {
        case .alarm_received: return "alarm.fill"
        case .friend_request: return "person.badge.plus"
        case .friend_accepted: return "person.2.fill"
        }
    }
}

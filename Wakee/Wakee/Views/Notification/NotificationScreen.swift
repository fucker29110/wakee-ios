import SwiftUI

struct NotificationScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    @State private var notifVM = NotificationViewModel()
    @State private var showProfile = false
    @State private var profileUid = ""
    @State private var handledRequests: Set<String> = []
    @State private var senderPhotos: [String: String] = [:]
    @State private var selectedActivityId: String?

    var body: some View {
        notificationList
            .background(AppTheme.Colors.background)
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { markReadButton }
            .navigationDestination(isPresented: $showProfile) {
                FriendProfileScreen(uid: profileUid)
            }
            .navigationDestination(item: $selectedActivityId) { activityId in
                PostDetailScreen(activityId: activityId, actorName: "ユーザー", targetName: nil)
            }
            .onAppear {
                guard let uid = authVM.user?.uid else { return }
                notifVM.subscribe(uid: uid)
            }
            .onChange(of: notifVM.notifications) { _, newValue in
                loadSenderPhotos(newValue)
            }
            .onDisappear { notifVM.unsubscribe() }
    }

    // MARK: - List

    @ViewBuilder
    private var notificationList: some View {
        if notifVM.isLoading {
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if notifVM.notifications.isEmpty {
            emptyState
        } else {
            List(notifVM.notifications) { notif in
                notificationRow(notif)
                    .listRowBackground(notif.read ? AppTheme.Colors.background : AppTheme.Colors.surface)
                    .listRowSeparatorTint(Color(hex: "#1F1F1F"))
            }
            .listStyle(.plain)
            .refreshable {
                guard let uid = authVM.user?.uid else { return }
                await notifVM.refresh(uid: uid)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.secondary)
            Text("通知はまだありません")
                .foregroundColor(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var markReadButton: some ToolbarContent {
        if notifVM.unreadCount > 0 {
            ToolbarItem(placement: .topBarTrailing) {
                Button("既読にする") {
                    guard let uid = authVM.user?.uid else { return }
                    notifVM.markAllAsRead(uid: uid)
                }
                .foregroundColor(AppTheme.Colors.accent)
                .font(.system(size: AppTheme.FontSize.sm))
            }
        }
    }

    // MARK: - Row

    private func notificationRow(_ notif: AppNotification) -> some View {
        VStack(spacing: 0) {
            notificationHeader(notif)
                .contentShape(Rectangle())
                .onTapGesture { handleTap(notif) }
            friendRequestActions(notif)
        }
        .padding(.vertical, 4)
    }

    private func handleTap(_ notif: AppNotification) {
        // 既読にする
        if let uid = authVM.user?.uid, let docID = notif.docID, !notif.read {
            Task { try? await NotificationHistoryService.shared.markAsRead(uid: uid, notificationId: docID) }
        }

        switch notif.type {
        case .friend_request, .friend_accepted:
            if DeepLinkManager.shared.navigateToProfile(uid: notif.senderUid, myUid: authVM.user?.uid) {
                profileUid = notif.senderUid
                showProfile = true
            }
        case .comment, .repost, .like:
            selectedActivityId = notif.relatedId
        case .message:
            if let chatId = notif.relatedId, !chatId.isEmpty {
                DeepLinkManager.shared.pendingChatId = chatId
            }
            DeepLinkManager.shared.pendingTab = 3
        case .alarm_received:
            break
        }
    }

    // MARK: - Header

    private func notificationHeader(_ notif: AppNotification) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            avatarBadge(notif)
            notificationText(notif)
            Spacer()
            unreadDot(notif)
        }
    }

    private func avatarBadge(_ notif: AppNotification) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(name: notif.senderName, photoURL: senderPhotos[notif.senderUid], size: 40)
            Image(systemName: notificationIcon(notif.type))
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(3)
                .background(Circle().fill(AppTheme.Colors.accent))
                .offset(x: 4, y: 4)
        }
        .onTapGesture {
            if DeepLinkManager.shared.navigateToProfile(uid: notif.senderUid, myUid: authVM.user?.uid) {
                profileUid = notif.senderUid
                showProfile = true
            }
        }
    }

    private func notificationText(_ notif: AppNotification) -> some View {
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
    }

    @ViewBuilder
    private func unreadDot(_ notif: AppNotification) -> some View {
        if !notif.read {
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Friend Request Actions

    @ViewBuilder
    private func friendRequestActions(_ notif: AppNotification) -> some View {
        if notif.type == .friend_request, let requestId = notif.relatedId, !requestId.isEmpty {
            let isHandled = notif.read || handledRequests.contains(requestId)
            if !isHandled {
                friendRequestButtons(notif: notif, requestId: requestId)
            } else {
                handledLabel
            }
        }
    }

    private var handledLabel: some View {
        HStack {
            Spacer().frame(width: 48)
            Text("対応済み")
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
            Spacer()
        }
        .padding(.top, AppTheme.Spacing.xs)
    }

    private func friendRequestButtons(notif: AppNotification, requestId: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Spacer().frame(width: 48)
            acceptButton(notif: notif, requestId: requestId)
            rejectButton(notif: notif, requestId: requestId)
            Spacer()
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    private func acceptButton(notif: AppNotification, requestId: String) -> some View {
        Button {
            guard let uid = authVM.user?.uid else { return }
            handledRequests.insert(requestId)
            Task {
                await friendsVM.acceptRequest(requestId: requestId, fromUid: notif.senderUid, toUid: uid)
                if let docID = notif.docID {
                    try? await NotificationHistoryService.shared.markAsRead(uid: uid, notificationId: docID)
                }
            }
        } label: {
            Text("承認")
                .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.Colors.accent))
        }
    }

    private func rejectButton(notif: AppNotification, requestId: String) -> some View {
        Button {
            guard let uid = authVM.user?.uid else { return }
            handledRequests.insert(requestId)
            Task {
                await friendsVM.rejectRequest(requestId: requestId)
                if let docID = notif.docID {
                    try? await NotificationHistoryService.shared.markAsRead(uid: uid, notificationId: docID)
                }
            }
        } label: {
            Text("拒否")
                .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                .foregroundColor(AppTheme.Colors.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().stroke(AppTheme.Colors.border))
        }
    }

    // MARK: - Helpers

    private func notificationIcon(_ type: NotificationType) -> String {
        switch type {
        case .alarm_received: return "alarm.fill"
        case .friend_request: return "person.badge.plus"
        case .friend_accepted: return "person.2.fill"
        case .comment: return "bubble.right.fill"
        case .repost: return "arrow.2.squarepath"
        case .like: return "heart.fill"
        case .message: return "envelope.fill"
        }
    }

    private func loadSenderPhotos(_ notifications: [AppNotification]) {
        let uids = Array(Set(notifications.map(\.senderUid)))
        let newUids = uids.filter { senderPhotos[$0] == nil }
        guard !newUids.isEmpty else { return }
        Task {
            let infos = await ActivityService.shared.getUserInfoByUids(newUids)
            await MainActor.run {
                for (uid, info) in infos {
                    if let url = info.photoURL {
                        senderPhotos[uid] = url
                    }
                }
            }
        }
    }
}

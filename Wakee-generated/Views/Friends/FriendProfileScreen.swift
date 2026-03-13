import SwiftUI

struct FriendProfileScreen: View {
    let uid: String

    @Environment(AuthViewModel.self) private var authVM
    @State private var profile: AppUser?
    @State private var friendStatus: FriendStatus = .loading
    @State private var receivedRequest: FollowRequest?
    @State private var isActing = false
    @State private var activities: [Activity] = []

    enum FriendStatus {
        case loading, friend, requestSent, requestReceived, none
    }

    var body: some View {
        ScrollView {
            if let profile {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Avatar & info
                    VStack(spacing: AppTheme.Spacing.md) {
                        AvatarView(name: profile.displayName, photoURL: profile.photoURL, size: 80)

                        Text(profile.displayName)
                            .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text("@\(profile.username)")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.primary)
                                .multilineTextAlignment(.center)
                        }

                        if !profile.location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12))
                                Text(profile.location)
                            }
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                        }
                    }

                    // Streak
                    HStack(spacing: AppTheme.Spacing.lg) {
                        statItem(value: "\(profile.streak)", label: "ストリーク")
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.BorderRadius.md)

                    // Action buttons
                    actionButtons

                    // Activity history
                    if !activities.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("アクティビティ")
                                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)

                            ForEach(activities.prefix(10)) { activity in
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: activityIcon(activity.type))
                                        .foregroundColor(AppTheme.Colors.accent)
                                        .frame(width: 24)
                                    Text(activityLabel(activity.type))
                                        .font(.system(size: AppTheme.FontSize.sm))
                                        .foregroundColor(AppTheme.Colors.primary)
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
                .padding(AppTheme.Spacing.md)
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .padding(.top, 80)
            }
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
    }

    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        switch friendStatus {
        case .friend:
            VStack(spacing: AppTheme.Spacing.sm) {
                NavigationLink {
                    ChatRoomDestination(otherUid: uid, otherUserName: profile?.displayName ?? "")
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "bubble.left.fill")
                        Text("メッセージ")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .fill(AppTheme.accentGradient)
                    )
                }

                Button(action: blockUser) {
                    Text("ブロック")
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.danger)
                }
            }

        case .requestSent:
            Text("フレンド申請を送信済み")
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundColor(AppTheme.Colors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                        .fill(AppTheme.Colors.surface)
                )

        case .requestReceived:
            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: acceptRequest) {
                    Text("承認する")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .fill(AppTheme.Colors.accent)
                        )
                }
                Button(action: rejectRequest) {
                    Text("拒否する")
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .stroke(AppTheme.Colors.border)
                        )
                }
            }

        case .none:
            Button(action: sendRequest) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "person.badge.plus")
                    Text("フレンド申請")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                        .fill(AppTheme.accentGradient)
                )
            }

        case .loading:
            ProgressView().tint(AppTheme.Colors.accent)
        }
    }

    // MARK: - Helpers
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.accent)
            Text(label)
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
        }
    }

    private func loadProfile() async {
        guard let myUid = authVM.user?.uid else { return }
        do {
            profile = try await FriendService.shared.getUserByUid(uid)
            let isFriend = try await FriendService.shared.checkFriendship(uid1: myUid, uid2: uid)
            if isFriend {
                friendStatus = .friend
            } else {
                let sentStatus = try await FriendService.shared.checkSentRequest(fromUid: myUid, toUid: uid)
                if sentStatus == "pending" {
                    friendStatus = .requestSent
                } else {
                    let received = try await FriendService.shared.getReceivedRequest(fromUid: uid, toUid: myUid)
                    if let received {
                        receivedRequest = received
                        friendStatus = .requestReceived
                    } else {
                        friendStatus = .none
                    }
                }
            }
        } catch {
            print("Load profile error: \(error)")
        }
    }

    private func sendRequest() {
        guard let me = authVM.user else { return }
        Task {
            _ = try? await FriendService.shared.sendFollowRequest(fromUid: me.uid, toUid: uid, fromName: me.displayName)
            friendStatus = .requestSent
        }
    }

    private func acceptRequest() {
        guard let myUid = authVM.user?.uid, let request = receivedRequest else { return }
        Task {
            try? await FriendService.shared.acceptRequest(requestId: request.id, fromUid: request.fromUid, toUid: myUid)
            friendStatus = .friend
        }
    }

    private func rejectRequest() {
        guard let request = receivedRequest else { return }
        Task {
            try? await FriendService.shared.rejectRequest(requestId: request.id)
            friendStatus = .none
        }
    }

    private func blockUser() {
        guard let myUid = authVM.user?.uid else { return }
        Task {
            try? await FriendService.shared.blockUser(myUid: myUid, targetUid: uid)
        }
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

// Helper view for chat navigation from friend profile
struct ChatRoomDestination: View {
    let otherUid: String
    let otherUserName: String
    @Environment(AuthViewModel.self) private var authVM
    @State private var chatId: String?

    var body: some View {
        Group {
            if let chatId {
                ChatRoomScreen(chatId: chatId, otherUserName: otherUserName, otherUserUid: otherUid)
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .task {
                        guard let myUid = authVM.user?.uid else { return }
                        chatId = try? await ChatService.shared.getOrCreateChat(uid1: myUid, uid2: otherUid)
                    }
            }
        }
    }
}

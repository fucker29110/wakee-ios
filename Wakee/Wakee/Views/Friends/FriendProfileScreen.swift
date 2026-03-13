import SwiftUI

struct FriendProfileScreen: View {
    let uid: String

    @Environment(AuthViewModel.self) private var authVM
    @State private var profile: AppUser?
    @State private var friendStatus: FriendStatus = .loading
    @State private var receivedRequest: FollowRequest?
    @State private var profileVM = ProfileViewModel()
    @State private var selectedActivity: Activity?
    @State private var showTargetProfile = false
    @State private var targetProfileUid: String = ""
    @State private var mutualFriends: [AppUser] = []
    @State private var showBlockAlert = false

    enum FriendStatus {
        case loading, friend, requestSent, requestReceived, none, blocked
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

                    // Stats（ProfileScreen と同じ4項目）
                    HStack(spacing: AppTheme.Spacing.xl) {
                        NavigationLink {
                            FriendFriendsListScreen(uid: uid, displayName: profile.displayName)
                        } label: {
                            statItem(value: "\(profileVM.friendCount)", label: "フレンド")
                        }
                        .buttonStyle(.plain)

                        statItem(value: "\(profileVM.wakeUpSentCount)", label: "起こした")
                        statItem(value: "\(profileVM.wokeUpCount)", label: "起こされた")
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.BorderRadius.md)

                    // Action buttons
                    actionButtons

                    // Mutual friends section
                    if !mutualFriends.isEmpty {
                        NavigationLink {
                            MutualFriendsListScreen(friends: mutualFriends, displayName: profile.displayName)
                        } label: {
                            HStack(spacing: 0) {
                                // Overlapping avatars (max 3)
                                ZStack {
                                    ForEach(Array(mutualFriends.prefix(3).enumerated()), id: \.element.uid) { index, friend in
                                        AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 28)
                                            .overlay(Circle().stroke(AppTheme.Colors.background, lineWidth: 2))
                                            .offset(x: CGFloat(index) * 18)
                                    }
                                }
                                .frame(width: CGFloat(min(mutualFriends.count, 3) - 1) * 18 + 28, alignment: .leading)

                                Text("共通のフレンド \(mutualFriends.count)人")
                                    .font(.system(size: AppTheme.FontSize.sm))
                                    .foregroundColor(AppTheme.Colors.secondary)
                                    .padding(.leading, AppTheme.Spacing.sm)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.secondary)
                            }
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.BorderRadius.md)
                        }
                        .buttonStyle(.plain)
                    }

                }
                .padding(AppTheme.Spacing.md)

                // Timeline (friends only)
                if friendStatus == .friend {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("アクティビティ")
                            .font(.system(size: AppTheme.FontSize.md, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.top, AppTheme.Spacing.sm)
                            .padding(.bottom, AppTheme.Spacing.xs)
                    }

                    if profileVM.isLoadingActivities {
                        ProgressView()
                            .tint(AppTheme.Colors.accent)
                            .padding(.top, 20)
                    } else {
                        let timelineActivities = profileVM.activities.filter { $0.type == .achieved || $0.type == .received_wakeup || $0.type == .repost || $0.type == .sent }
                        if timelineActivities.isEmpty {
                            VStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.Colors.secondary)
                                Text("まだアクティビティがありません")
                                    .font(.system(size: AppTheme.FontSize.sm))
                                    .foregroundColor(AppTheme.Colors.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.xl)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(timelineActivities) { activity in
                                FeedItemView(
                                    activity: activity,
                                    userMap: profileVM.userMap,
                                    activityLabel: activity.feedLabel,
                                    activityIcon: activity.feedIcon,
                                    sourceActivity: activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] },
                                    onTap: {
                                        selectedActivity = activity
                                    },
                                    onLikeTap: {
                                        guard let user = authVM.user else { return }
                                        Task { try? await LikeService.shared.toggleLike(activityId: activity.id, userId: user.uid, senderUsername: user.username, senderName: user.displayName) }
                                    },
                                    isLiked: activity.likedBy?.contains(authVM.user?.uid ?? "") == true,
                                    onTargetProfileTap: {
                                        if let tuid = activity.targetUid,
                                           DeepLinkManager.shared.navigateToProfile(uid: tuid, myUid: authVM.user?.uid) {
                                            targetProfileUid = tuid
                                            showTargetProfile = true
                                        }
                                    },
                                    onActorProfileTap: {
                                        if DeepLinkManager.shared.navigateToProfile(uid: activity.actorUid, myUid: authVM.user?.uid) {
                                            targetProfileUid = activity.actorUid
                                            showTargetProfile = true
                                        }
                                    },
                                    onSourceActorProfileTap: {
                                        let src = activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] }
                                        let uid = src?.actorUid ?? activity.targetUid ?? ""
                                        if !uid.isEmpty, DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                            targetProfileUid = uid
                                            showTargetProfile = true
                                        }
                                    },
                                    onSourceTargetProfileTap: {
                                        let src = activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] }
                                        if let uid = src?.targetUid,
                                           DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                            targetProfileUid = uid
                                            showTargetProfile = true
                                        }
                                    },
                                    showPrivateBadge: false
                                )
                            }
                        }
                        }
                    }
                } else if friendStatus != .loading {
                    // Non-friend: locked activity message
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text("フレンドになるとアクティビティが見れます")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.xl)
                }
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .padding(.top, 80)
            }
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedActivity) { activity in
            let actorName = profileVM.userMap[activity.actorUid]?.displayName ?? "ユーザー"
            let targetName = activity.targetUid.flatMap { profileVM.userMap[$0]?.displayName }
            PostDetailScreen(activityId: activity.id, actorName: actorName, targetName: targetName)
        }
        .navigationDestination(isPresented: $showTargetProfile) {
            FriendProfileScreen(uid: targetProfileUid)
        }
        .task {
            profileVM.subscribeFriendCount(uid: uid)
            await loadProfile()
        }
        .onChange(of: friendStatus) { _, newStatus in
            if newStatus == .friend {
                profileVM.subscribeActivities(uid: uid, isOwnProfile: false, viewerUid: authVM.user?.uid ?? "")
            }
        }
        .alert("ブロック", isPresented: $showBlockAlert) {
            Button("ブロックする", role: .destructive) { confirmBlock() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(profile?.displayName ?? "このユーザー")をブロックしますか？フレンド関係も解除されます。")
        }
        .onDisappear {
            profileVM.unsubscribe()
        }
    }

    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        if uid == authVM.user?.uid {
            EmptyView()
        } else {
            switch friendStatus {
        case .friend:
            HStack(spacing: AppTheme.Spacing.sm) {
                NavigationLink {
                    ChatRoomDestination(otherUid: uid, otherUserName: profile?.displayName ?? "")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14))
                        Text("メッセージ")
                    }
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .stroke(AppTheme.Colors.secondary, lineWidth: 1)
                    )
                }

                Button { showBlockAlert = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "nosign")
                            .font(.system(size: 14))
                        Text("ブロック")
                    }
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .stroke(AppTheme.Colors.secondary, lineWidth: 1)
                    )
                }
            }

        case .blocked:
            Button(action: unblockUser) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("ブロック解除")
                }
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                        .stroke(AppTheme.Colors.border)
                )
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
    }

    // MARK: - Helpers
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

    private func loadProfile() async {
        guard let myUid = authVM.user?.uid else { return }
        // 自分自身のプロフィールの場合
        if uid == myUid {
            profile = authVM.user
            friendStatus = .none
            return
        }
        do {
            // Check blocked first
            if authVM.user?.settings.blocked.contains(uid) == true {
                profile = try await FriendService.shared.getUserByUid(uid)
                friendStatus = .blocked
                return
            }

            async let fetchedProfile = FriendService.shared.getUserByUid(uid)
            async let fetchedMutualFriends = FriendService.shared.getMutualFriends(myUid: myUid, otherUid: uid)
            profile = try await fetchedProfile
            mutualFriends = (try? await fetchedMutualFriends) ?? []
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
            friendStatus = .none
        }
    }

    private func sendRequest() {
        guard let me = authVM.user else { return }
        Task {
            _ = try? await FriendService.shared.sendFollowRequest(fromUid: me.uid, toUid: uid, fromName: me.displayName, fromUsername: me.username)
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

    private func confirmBlock() {
        guard let myUid = authVM.user?.uid else { return }
        Task {
            try? await FriendService.shared.blockUser(myUid: myUid, targetUid: uid)
            authVM.user?.settings.blocked.append(uid)
            friendStatus = .blocked
            profileVM.unsubscribe()
        }
    }

    private func unblockUser() {
        guard let myUid = authVM.user?.uid else { return }
        Task {
            try? await FriendService.shared.unblockUser(myUid: myUid, targetUid: uid)
            authVM.user?.settings.blocked.removeAll { $0 == uid }
            friendStatus = .none
        }
    }

}

// Helper view for chat navigation from friend profile
struct ChatRoomDestination: View {
    let otherUid: String
    let otherUserName: String
    @Environment(AuthViewModel.self) private var authVM
    @State private var chatId: String?
    @State private var hasError = false

    var body: some View {
        Group {
            if let chatId {
                ChatRoomScreen(chatId: chatId, otherUserName: otherUserName, otherUserUid: otherUid)
            } else if hasError {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text("チャットを開けませんでした")
                        .foregroundColor(AppTheme.Colors.primary)
                    Button("再試行") {
                        hasError = false
                        Task { await loadChat() }
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                }
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .task { await loadChat() }
            }
        }
    }

    private func loadChat() async {
        guard let myUid = authVM.user?.uid else {
            hasError = true
            return
        }
        do {
            let id = try await ChatService.shared.getOrCreateChat(uid1: myUid, uid2: otherUid)
            chatId = id
        } catch {
            print("[ChatRoomDestination] Error: \(error)")
            hasError = true
        }
    }
}

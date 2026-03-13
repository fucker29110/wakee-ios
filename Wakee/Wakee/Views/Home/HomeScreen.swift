import SwiftUI
import FirebaseFirestore

struct HomeScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    @State private var homeVM = HomeViewModel()
    @State private var storyVM = StoryViewModel()
    @State private var notifUnreadCount = 0
    @State private var notifListener: ListenerRegistration?
    @State private var showStoryCreate = false
    @State private var viewingStory: Story?
    @State private var selectedActivity: Activity?
    @State private var repostTarget: Activity?
    @State private var showTargetProfile = false
    @State private var targetProfileUid: String = ""
    @State private var pendingPostDetailId: String?
    @State private var deleteTarget: Activity?

    var body: some View 		{
        ScrollView {
            VStack(spacing: 0) {
                storySection
                feedSection
            }
        }
        .refreshable {
            guard let uid = authVM.user?.uid else { return }
            await homeVM.refresh(uid: uid)
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(item: $selectedActivity) { activity in
            let actorName = homeVM.userMap[activity.actorUid]?.displayName ?? "ユーザー"
            let targetName = activity.targetUid.flatMap { homeVM.userMap[$0]?.displayName }
            PostDetailScreen(activityId: activity.id, actorName: actorName, targetName: targetName)
        }
        .navigationDestination(for: String.self) { value in
            if value == "notifications" {
                NotificationScreen()
            }
        }
        .navigationDestination(isPresented: $showTargetProfile) {
            FriendProfileScreen(uid: targetProfileUid)
        }
        .navigationDestination(item: $pendingPostDetailId) { activityId in
            PostDetailScreen(activityId: activityId, actorName: "ユーザー", targetName: nil)
        }
        .sheet(isPresented: $showStoryCreate) { storyCreateSheet }
        .sheet(item: $viewingStory) { story in storyViewSheet(story) }
        .alert("投稿を削除", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("削除する", role: .destructive) {
                guard let target = deleteTarget else { return }
                Task { try? await ActivityService.shared.deleteActivity(activityId: target.id) }
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("この投稿を削除しますか？")
        }
        .sheet(item: $repostTarget) { target in
            RepostSheet(activity: target, userMap: homeVM.userMap, myFriendUids: friendsVM.friends.map(\.uid)) {
                repostTarget = nil
            }
            .environment(authVM)
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            homeVM.subscribe(uid: uid)
            notifListener?.remove()
            notifListener = NotificationHistoryService.shared.subscribeUnreadCount(uid: uid) { count in
                notifUnreadCount = count
            }
        }
        .onDisappear {
            homeVM.unsubscribe()
            storyVM.unsubscribe()
            notifListener?.remove()
            notifListener = nil
        }
        .onChange(of: friendsVM.friends) { _, friends in
            guard let uid = authVM.user?.uid else { return }
            let friendUids = friends.map(\.uid)
            storyVM.subscribe(uid: uid, friendUids: friendUids)
        }
        .onChange(of: homeVM.isLoading) { _, isLoading in
            guard !isLoading else { return }
            handlePendingActivityNavigation()
        }
        .onChange(of: homeVM.activities) { _, _ in
            handlePendingActivityNavigation()
        }
    }

    // MARK: - Story Section

    private var storySection: some View {
        StoryRow(
            myStory: storyVM.myStory,
            stories: storyVM.stories,
            userMap: homeVM.userMap,
            myUid: authVM.user?.uid ?? "",
            onCreateTap: { showStoryCreate = true },
            onStoryTap: { story in viewingStory = story }
        )
    }

    // MARK: - Feed Section

    @ViewBuilder
    private var feedSection: some View {
        if homeVM.isLoading {
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .padding(.top, 40)
        } else if homeVM.activities.isEmpty {
            emptyFeed
        } else {
            LazyVStack(spacing: 0) {
                ForEach(filteredActivities) { activity in
                    feedItemView(for: activity)
                }
            }
        }
    }

    private func feedItemView(for activity: Activity) -> some View {
        let myUid = authVM.user?.uid ?? ""
        return FeedItemView(
            activity: activity,
            userMap: homeVM.userMap,
            activityLabel: activity.feedLabel,
            activityIcon: activity.feedIcon,
            sourceActivity: activity.repostSourceId.flatMap { homeVM.sourceActivities[$0] },
            onTap: {
                selectedActivity = activity
            },
            onRepostTap: {
                repostTarget = activity
            },
            onLikeTap: {
                guard let user = authVM.user else { return }
                Task { try? await LikeService.shared.toggleLike(activityId: activity.id, userId: user.uid, senderUsername: user.username, senderName: user.displayName) }
            },
            isLiked: activity.likedBy?.contains(myUid) == true,
            onTargetProfileTap: {
                if let uid = activity.targetUid,
                   DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                    targetProfileUid = uid
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
                let src = activity.repostSourceId.flatMap { homeVM.sourceActivities[$0] }
                let uid = src?.actorUid ?? activity.targetUid ?? ""
                if !uid.isEmpty, DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                    targetProfileUid = uid
                    showTargetProfile = true
                }
            },
            onSourceTargetProfileTap: {
                let src = activity.repostSourceId.flatMap { homeVM.sourceActivities[$0] }
                if let uid = src?.targetUid,
                   DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                    targetProfileUid = uid
                    showTargetProfile = true
                }
            },
            onDeleteTap: activity.actorUid == myUid ? {
                deleteTarget = activity
            } : nil
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Wakee")
                .font(.system(size: AppTheme.FontSize.xl, weight: .heavy))
                .foregroundStyle(AppTheme.accentGradient)
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: "notifications") {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                    if notifUnreadCount > 0 {
                        BadgeView(count: notifUnreadCount)
                            .offset(x: 10, y: -8)
                    }
                }
            }
        }
    }

    // MARK: - Sheets

    private var storyCreateSheet: some View {
        StoryCreateModal(
            existingText: storyVM.myStory?.text,
            onPost: { text in
                guard let uid = authVM.user?.uid else { return }
                Task { await storyVM.postStory(uid: uid, text: text) }
            },
            onDelete: {
                guard let storyId = storyVM.myStory?.id else { return }
                Task { await storyVM.deleteStory(storyId: storyId) }
            }
        )
    }

    private func storyViewSheet(_ story: Story) -> some View {
        StoryViewModal(
            story: story,
            authorName: homeVM.userMap[story.authorUid]?.displayName ?? "ユーザー",
            authorPhotoURL: homeVM.userMap[story.authorUid]?.photoURL,
            isMyStory: story.authorUid == authVM.user?.uid,
            onRead: {
                guard let uid = authVM.user?.uid else { return }
                storyVM.markAsRead(storyId: story.id, uid: uid)
            },
            onEdit: { text in
                Task { await storyVM.editStory(storyId: story.id, text: text) }
            },
            onDelete: {
                Task { await storyVM.deleteStory(storyId: story.id) }
            }
        )
    }

    // MARK: - Helpers

    private func handlePendingActivityNavigation() {
        guard let activityId = DeepLinkManager.shared.pendingActivityId else { return }
        guard !homeVM.isLoading else { return }
        DeepLinkManager.shared.pendingActivityId = nil
        if let activity = homeVM.activities.first(where: { $0.id == activityId }) {
            selectedActivity = activity
        } else {
            pendingPostDetailId = activityId
        }
    }

    private var filteredActivities: [Activity] {
        homeVM.activities.filter { $0.type != .sent && $0.type != .received_wakeup }
    }

    private var emptyFeed: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "sun.max")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.secondary)
            Text("まだアクティビティがありません")
                .foregroundColor(AppTheme.Colors.primary)
            Text("フレンドにアラームを送ってみよう！")
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .padding(.top, 80)
    }
}

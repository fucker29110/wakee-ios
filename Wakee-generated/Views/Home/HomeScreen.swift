import SwiftUI

struct HomeScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var homeVM = HomeViewModel()
    @State private var storyVM = StoryViewModel()
    @State private var friendsVM = FriendsViewModel()
    @State private var showStoryCreate = false
    @State private var viewingStory: Story?
    @State private var showRepostModal = false
    @State private var repostTarget: Activity?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Story row
                StoryRow(
                    myStory: storyVM.myStory,
                    stories: storyVM.stories,
                    userMap: homeVM.userMap,
                    myUid: authVM.user?.uid ?? "",
                    onCreateTap: { showStoryCreate = true },
                    onStoryTap: { story in viewingStory = story }
                )

                // Feed
                if homeVM.isLoading {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .padding(.top, 40)
                } else if homeVM.activities.isEmpty {
                    emptyFeed
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredActivities) { activity in
                            NavigationLink(value: activity) {
                                FeedItemView(
                                    activity: activity,
                                    userMap: homeVM.userMap,
                                    activityLabel: homeVM.activityLabel(activity),
                                    activityIcon: homeVM.activityIcon(activity)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarRight) {
                NavigationLink(value: "notifications") {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .navigationDestination(for: Activity.self) { activity in
            let actorName = homeVM.userMap[activity.actorUid]?.displayName ?? "ユーザー"
            let targetName = activity.targetUid.flatMap { homeVM.userMap[$0]?.displayName }
            PostDetailScreen(activityId: activity.id, actorName: actorName, targetName: targetName)
        }
        .navigationDestination(for: String.self) { value in
            if value == "notifications" {
                NotificationScreen()
            }
        }
        .sheet(isPresented: $showStoryCreate) {
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
        .sheet(item: $viewingStory) { story in
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
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            homeVM.subscribe(uid: uid)
            friendsVM.subscribe(uid: uid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let friendUids = friendsVM.friends.map(\.uid)
                storyVM.subscribe(uid: uid, friendUids: friendUids)
            }
        }
        .onDisappear {
            homeVM.unsubscribe()
            storyVM.unsubscribe()
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

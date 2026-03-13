import SwiftUI
import FirebaseFirestore

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var selectedTab = 0
    @State private var chatUnreadCount = 0
    @State private var notificationUnreadCount = 0
    @State private var chatListener: ListenerRegistration?
    @State private var notifListener: ListenerRegistration?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeScreen()
                }
                .tag(0)

                NavigationStack {
                    FriendsListScreen()
                }
                .tag(1)

                NavigationStack {
                    CreateAlarmScreen()
                }
                .tag(2)

                NavigationStack {
                    ChatListScreen()
                }
                .tag(3)

                NavigationStack {
                    ProfileScreen()
                }
                .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)

            // Custom tab bar
            customTabBar
        }
        .onAppear { setupListeners() }
        .onDisappear { removeListeners() }
    }

    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house.fill", label: "ホーム", tag: 0)
            tabButton(icon: "person.2.fill", label: "フレンド", tag: 1)
            centerAlarmButton
            chatTabButton
            tabButton(icon: "person.fill", label: "プロフィール", tag: 4)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(
            AppTheme.Colors.surface
                .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(icon: String, label: String, tag: Int, badgeCount: Int = 0) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                    if badgeCount > 0 {
                        BadgeView(count: badgeCount)
                            .offset(x: 10, y: -8)
                    }
                }
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tag ? AppTheme.Colors.tabActive : AppTheme.Colors.tabInactive)
            .frame(maxWidth: .infinity)
        }
    }

    private var chatTabButton: some View {
        Button(action: { selectedTab = 3 }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 20))
                    if chatUnreadCount > 0 {
                        BadgeView(count: chatUnreadCount)
                            .offset(x: 10, y: -8)
                    }
                }
                Text("チャット")
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == 3 ? AppTheme.Colors.tabActive : AppTheme.Colors.tabInactive)
            .frame(maxWidth: .infinity)
        }
    }

    private var centerAlarmButton: some View {
        Button(action: { selectedTab = 2 }) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 8, y: 2)
                Image(systemName: "alarm.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .offset(y: -20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Listeners
    private func setupListeners() {
        guard let uid = authVM.user?.uid else { return }
        chatListener = ChatService.shared.subscribeChats(uid: uid) { chats in
            chatUnreadCount = chats.reduce(0) { $0 + $1.unreadFor(uid: uid) }
        }
        notifListener = NotificationHistoryService.shared.subscribeUnreadCount(uid: uid) { count in
            notificationUnreadCount = count
        }
    }

    private func removeListeners() {
        chatListener?.remove()
        notifListener?.remove()
    }
}

import SwiftUI
import FirebaseFirestore

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var selectedTab = 0
    @State private var chatUnreadCount = 0
    @State private var chatListener: ListenerRegistration?
    @State private var friendsVM = FriendsViewModel()
    @State private var appearedTabs: Set<Int> = [0]
    @State private var isKeyboardVisible = false
    @State private var showNotificationModal = false
    @State private var showFocusModeModal = false
    private var deepLink = DeepLinkManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeScreen()
                }
                .tag(0)

                NavigationStack {
                    lazyTab(1) { FriendsListScreen() }
                }
                .tag(1)

                NavigationStack {
                    lazyTab(2) { CreateAlarmScreen() }
                }
                .tag(2)

                NavigationStack {
                    lazyTab(3) { ChatListScreen() }
                }
                .tag(3)

                NavigationStack {
                    lazyTab(4) { ProfileScreen() }
                }
                .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)

            // Custom tab bar（キーボード表示中は非表示）
            if !isKeyboardVisible {
                customTabBar
            }
        }
        .environment(friendsVM)
        .onAppear { setupListeners() }
        .onDisappear { removeListeners() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { isKeyboardVisible = false }
        }
        .onChange(of: selectedTab) { _, newTab in
            appearedTabs.insert(newTab)
        }
        .onChange(of: deepLink.pendingTab) { _, newTab in
            guard let tab = newTab else { return }
            selectedTab = tab
            deepLink.pendingTab = nil
        }
        .task {
            if await NotificationSettingsModal.shouldShow() {
                showNotificationModal = true
            }
        }
        .sheet(isPresented: $showNotificationModal) {
            NotificationSettingsModal()
                .environment(lang)
                .presentationDetents([.medium])
        }
        .onAppear {
            if let uid = authVM.user?.uid, FocusModeModal.shouldShow(uid: uid) {
                showFocusModeModal = true
            }
        }
        .sheet(isPresented: $showFocusModeModal) {
            FocusModeModal(uid: authVM.user?.uid ?? "")
                .environment(lang)
                .presentationDetents([.large])
        }
    }

    // MARK: - Lazy Tab Loading

    @ViewBuilder
    private func lazyTab<Content: View>(_ tag: Int, @ViewBuilder content: () -> Content) -> some View {
        if appearedTabs.contains(tag) {
            content()
        } else {
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
        }
    }

    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house.fill", label: lang.l("tab.home"), tag: 0)
            tabButton(icon: "person.2.fill", label: lang.l("tab.friends"), tag: 1)
            centerAlarmButton
            chatTabButton
            tabButton(icon: "person.fill", label: lang.l("tab.profile"), tag: 4)
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
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                    if chatUnreadCount > 0 {
                        BadgeView(count: chatUnreadCount)
                            .offset(x: 10, y: -8)
                    }
                }
                Text(lang.l("tab.chat"))
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
        friendsVM.subscribe(uid: uid)
        chatListener?.remove()
        chatListener = ChatService.shared.subscribeChats(uid: uid) { chats in
            chatUnreadCount = chats.reduce(0) { $0 + $1.unreadFor(uid: uid) }
        }
    }

    private func removeListeners() {
        friendsVM.unsubscribe()
        chatListener?.remove()
        chatListener = nil
    }
}

import SwiftUI

struct ChatNavTarget: Hashable {
    let chatId: String
    let friendName: String
    let friendUid: String
}

struct FriendsListScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    var initialTab: Int = 0
    @State private var activeTab = 0
    @State private var chatTarget: ChatNavTarget?
    @State private var showChat = false
    @State private var isLoadingChat = false
    @State private var copiedLink = false
    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                tabButton(title: "フレンドを探す", count: nil, tag: 0)
                tabButton(title: "フレンド", count: friendsVM.friends.count, tag: 1)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)

            switch activeTab {
            case 0: suggestionsTab
            case 1: friendsList
            default: EmptyView()
            }
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Wakee")
                    .font(.system(size: AppTheme.FontSize.xl, weight: .heavy))
                    .foregroundStyle(AppTheme.accentGradient)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            FriendSearchSheet(friendsVM: friendsVM)
                .environment(authVM)
        }
        .navigationDestination(isPresented: $showChat) {
            if let target = chatTarget {
                ChatRoomScreen(chatId: target.chatId, otherUserName: target.friendName, otherUserUid: target.friendUid)
            }
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            activeTab = initialTab
            Task { await friendsVM.fetchSuggestions(uid: uid) }
        }
    }

    // MARK: - Tab Button
    private func tabButton(title: String, count: Int?, tag: Int) -> some View {
        Button(action: { withAnimation { activeTab = tag } }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .fontWeight(activeTab == tag ? .semibold : .regular)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(activeTab == tag ? AppTheme.Colors.accent : AppTheme.Colors.surfaceVariant)
                            )
                            .foregroundColor(.white)
                    }
                }
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundColor(activeTab == tag ? AppTheme.Colors.primary : AppTheme.Colors.secondary)

                Rectangle()
                    .fill(activeTab == tag ? AppTheme.Colors.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestions Tab
    private var suggestionsTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                inviteBanner
                suggestionsList
            }
        }
    }

    // MARK: - Invite Banner
    private var inviteBanner: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.accentGradient)

            Text("友達をWakeeに招待しよう")
                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)

            Text("リンクをシェアして友達を追加")
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)

            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: shareInviteLink) {
                    Label("友達を招待する", systemImage: "square.and.arrow.up")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.accentGradient))
                }

                Button(action: copyInviteLink) {
                    Label(copiedLink ? "コピー済み" : "リンクコピー", systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(copiedLink ? AppTheme.Colors.success : AppTheme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(AppTheme.Colors.border, lineWidth: 1))
                }
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
    }

    private var inviteLink: String {
        guard let username = authVM.user?.username else { return "https://wakee.app" }
        return "https://wakee.app/invite/\(username)"
    }

    private func shareInviteLink() {
        let activityVC = UIActivityViewController(
            activityItems: ["Wakeeで一緒に早起きしよう！ \(inviteLink)"],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteLink
        copiedLink = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { copiedLink = false }
        }
    }

    // MARK: - Suggestions List
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("おすすめの友達")
                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.sm)

            if friendsVM.isLoadingSuggestions {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.xl)
            } else if friendsVM.suggestions.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text("おすすめはまだありません")
                        .foregroundColor(AppTheme.Colors.secondary)
                        .font(.system(size: AppTheme.FontSize.sm))
                    Text("友達が増えると表示されます")
                        .foregroundColor(AppTheme.Colors.secondary)
                        .font(.system(size: AppTheme.FontSize.xs))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(friendsVM.suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: SuggestedFriend) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            NavigationLink {
                FriendProfileScreen(uid: suggestion.user.uid)
            } label: {
                AvatarView(name: suggestion.user.displayName, photoURL: suggestion.user.photoURL, size: 44)
            }
            .buttonStyle(.plain)

            NavigationLink {
                FriendProfileScreen(uid: suggestion.user.uid)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.user.displayName)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("共通の友達 \(suggestion.mutualCount)人")
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if friendsVM.sentRequests.contains(suggestion.user.uid) {
                Text("申請済み")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                Button(action: {
                    guard let me = authVM.user else { return }
                    Task { await friendsVM.sendRequest(fromUid: me.uid, toUid: suggestion.user.uid, fromName: me.displayName, fromUsername: me.username) }
                }) {
                    Text("追加")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Friends List
    private var friendsList: some View {
        Group {
            if friendsVM.friends.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text("フレンドがいません")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("おすすめタブから友達を追加しましょう")
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(friendsVM.friends) { friend in
                            friendRow(friend)
                        }
                    }
                }
            }
        }
    }

    private func friendRow(_ friend: AppUser) -> some View {
        NavigationLink {
            FriendProfileScreen(uid: friend.uid)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("@\(friend.username)")
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }

    private func openChat(with friend: AppUser) {
        guard let myUid = authVM.user?.uid else { return }
        isLoadingChat = true
        Task {
            do {
                let chatId = try await ChatService.shared.getOrCreateChat(uid1: myUid, uid2: friend.uid)
                await MainActor.run {
                    isLoadingChat = false
                    chatTarget = ChatNavTarget(chatId: chatId, friendName: friend.displayName, friendUid: friend.uid)
                    showChat = true
                }
            } catch {
                await MainActor.run { isLoadingChat = false }
            }
        }
    }
}

// MARK: - Friend Search Sheet
struct FriendSearchSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Bindable var friendsVM: FriendsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                HStack {
                    TextField("ユーザー名で検索", text: $friendsVM.searchQuery)
                        .textFieldStyle(DarkTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            guard let uid = authVM.user?.uid else { return }
                            Task { await friendsVM.search(myUid: uid) }
                        }

                    Button(action: {
                        guard let uid = authVM.user?.uid else { return }
                        Task { await friendsVM.search(myUid: uid) }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.accent)
                            .cornerRadius(AppTheme.BorderRadius.sm)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)

                if friendsVM.isSearching {
                    ProgressView().tint(AppTheme.Colors.accent)
                    Spacer()
                } else if friendsVM.searchResults.isEmpty && !friendsVM.searchQuery.isEmpty {
                    Text("ユーザーが見つかりません")
                        .foregroundColor(AppTheme.Colors.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(friendsVM.searchResults) { user in
                                searchResultRow(user)
                            }
                        }
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("フレンド検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
    }

    private func searchResultRow(_ user: AppUser) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: user.displayName, photoURL: user.photoURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                Text("@\(user.username)")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()

            if friendsVM.sentRequests.contains(user.uid) {
                Text("申請済み")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            } else {
                Button(action: {
                    guard let me = authVM.user else { return }
                    Task { await friendsVM.sendRequest(fromUid: me.uid, toUid: user.uid, fromName: me.displayName, fromUsername: me.username) }
                }) {
                    Text("申請")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }
}

import SwiftUI

struct FriendsListScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var friendsVM = FriendsViewModel()
    @State private var activeTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                tabButton(title: "フレンド", count: friendsVM.friends.count, tag: 0)
                tabButton(title: "リクエスト", count: friendsVM.requests.count, tag: 1)
                tabButton(title: "検索", count: nil, tag: 2)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)

            switch activeTab {
            case 0: friendsList
            case 1: requestsList
            case 2: searchView
            default: EmptyView()
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("フレンド")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AppUser.self) { user in
            FriendProfileScreen(uid: user.uid)
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            friendsVM.subscribe(uid: uid)
        }
        .onDisappear { friendsVM.unsubscribe() }
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
                    Text("検索タブからフレンドを追加しましょう")
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(friendsVM.friends) { friend in
                            NavigationLink(value: friend) {
                                friendRow(friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func friendRow(_ friend: AppUser) -> some View {
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
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Requests List
    private var requestsList: some View {
        Group {
            if friendsVM.requests.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text("リクエストはありません")
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(friendsVM.requests) { request in
                            requestRow(request)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        }
    }

    private func requestRow(_ request: FollowRequest) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: request.fromName, photoURL: nil, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromName)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                Text("フレンド申請")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
            Button(action: {
                guard let uid = authVM.user?.uid else { return }
                Task { await friendsVM.acceptRequest(requestId: request.id, fromUid: request.fromUid, toUid: uid) }
            }) {
                Text("承認")
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.Colors.accent))
            }
            Button(action: {
                Task { await friendsVM.rejectRequest(requestId: request.id) }
            }) {
                Text("拒否")
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().stroke(AppTheme.Colors.border))
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
    }

    // MARK: - Search View
    @ViewBuilder
    private var searchView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack {
                TextField("ユーザー名で検索", text: Binding(
                    get: { friendsVM.searchQuery },
                    set: { friendsVM.searchQuery = $0 }
                ))
                .textFieldStyle(DarkTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

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
            } else if friendsVM.searchResults.isEmpty && !friendsVM.searchQuery.isEmpty {
                Text("ユーザーが見つかりません")
                    .foregroundColor(AppTheme.Colors.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(friendsVM.searchResults) { user in
                            searchResultRow(user)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }

            Spacer()
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
                    Task { await friendsVM.sendRequest(fromUid: me.uid, toUid: user.uid, fromName: me.displayName) }
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
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
    }
}

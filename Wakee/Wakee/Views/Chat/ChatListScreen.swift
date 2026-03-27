import SwiftUI

struct ChatListScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    @Environment(LanguageManager.self) private var lang
    @State private var chatVM = ChatViewModel()
    @State private var pendingChatTarget: PendingChat?
    @State private var showNewGroup = false

    struct PendingChat: Identifiable, Hashable {
        let id: String  // chatId
    }

    var body: some View {
        Group {
            if chatVM.isLoading {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chatVM.chats.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chatVM.chats) { chat in
                            if chat.isGroup == true {
                                groupChatLink(chat: chat)
                            } else {
                                directChatLink(chat: chat)
                            }
                        }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("chat.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewGroup = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showNewGroup) {
            NewGroupChatSheet { chatId in
                pendingChatTarget = PendingChat(id: chatId)
            }
        }
        .navigationDestination(item: $pendingChatTarget) { pending in
            let chat = chatVM.chats.first(where: { $0.id == pending.id })
            if let chat, chat.isGroup == true {
                let name = chatVM.groupDisplayName(chat: chat, myUid: authVM.user?.uid ?? "")
                ChatRoomScreen(chatId: chat.id, chat: chat, groupName: name)
            } else {
                let otherUid = chat?.otherUserId(myUid: authVM.user?.uid ?? "") ?? ""
                let name = chatVM.participantMap[otherUid]?.displayName ?? lang.l("common.user")
                ChatRoomScreen(chatId: pending.id, otherUserName: name, otherUserUid: otherUid)
            }
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            chatVM.subscribeChats(uid: uid)
            handlePendingChat()
        }
        .onChange(of: chatVM.chats.count) { _, _ in
            handlePendingChat()
        }
        .onDisappear { chatVM.unsubscribeChats() }
    }

    @ViewBuilder
    private func directChatLink(chat: Chat) -> some View {
        let otherUid = chat.otherUserId(myUid: authVM.user?.uid ?? "") ?? ""
        let info = chatVM.participantMap[otherUid]
        let name = info?.displayName ?? otherUid

        NavigationLink {
            ChatRoomScreen(chatId: chat.id, otherUserName: name, otherUserUid: otherUid)
        } label: {
            chatRow(
                chat: chat,
                name: name,
                photoURL: info?.photoURL,
                unread: chat.unreadFor(uid: authVM.user?.uid ?? ""),
                isGroup: false
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func groupChatLink(chat: Chat) -> some View {
        let myUid = authVM.user?.uid ?? ""
        let name = chatVM.groupDisplayName(chat: chat, myUid: myUid)

        NavigationLink {
            ChatRoomScreen(chatId: chat.id, chat: chat, groupName: name)
        } label: {
            chatRow(
                chat: chat,
                name: name,
                photoURL: chat.groupImageURL,
                unread: chat.unreadFor(uid: myUid),
                isGroup: true
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.secondary)
            Text(lang.l("chat.empty"))
                .foregroundColor(AppTheme.Colors.primary)
            Text(lang.l("chat.empty_hint"))
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handlePendingChat() {
        guard let chatId = DeepLinkManager.shared.pendingChatId else { return }
        guard !chatVM.chats.isEmpty else { return }
        DeepLinkManager.shared.pendingChatId = nil
        pendingChatTarget = PendingChat(id: chatId)
    }

    private func chatRow(chat: Chat, name: String, photoURL: String?, unread: Int, isGroup: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if isGroup {
                if let photoURL, !photoURL.isEmpty {
                    AvatarView(name: name, photoURL: photoURL, size: 48)
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.surfaceVariant)
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.3.fill")
                            .foregroundColor(AppTheme.Colors.accent)
                            .font(.system(size: 18))
                    }
                }
            } else {
                AvatarView(name: name, photoURL: photoURL, size: 48)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(TimeUtils.timeAgo(from: chat.lastMessageDate))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                }

                HStack {
                    Text(chat.lastMessage.isEmpty ? lang.l("chat.start") : chat.lastMessage)
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .lineLimit(1)

                    Spacer()

                    if unread > 0 {
                        BadgeView(count: unread)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 14)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }
}

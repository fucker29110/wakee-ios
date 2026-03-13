import SwiftUI

struct ChatListScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var chatVM = ChatViewModel()

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
                                    unread: chat.unreadFor(uid: authVM.user?.uid ?? "")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("チャット")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            chatVM.subscribeChats(uid: uid)
        }
        .onDisappear { chatVM.unsubscribeChats() }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.secondary)
            Text("チャットがまだありません")
                .foregroundColor(AppTheme.Colors.primary)
            Text("フレンドのプロフィールからメッセージを送れます")
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chatRow(chat: Chat, name: String, photoURL: String?, unread: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: name, photoURL: photoURL, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                    Spacer()
                    Text(TimeUtils.timeAgo(from: chat.lastMessageDate))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                }

                HStack {
                    Text(chat.lastMessage.isEmpty ? "メッセージを送ってみよう" : chat.lastMessage)
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

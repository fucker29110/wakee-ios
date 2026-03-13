import SwiftUI

struct ChatRoomScreen: View {
    let chatId: String
    let otherUserName: String
    let otherUserUid: String

    @Environment(AuthViewModel.self) private var authVM
    @State private var chatVM = ChatViewModel()
    @State private var text = ""
    @State private var isSending = false
    @State private var otherPhotoURL: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(chatVM.messages.reversed()) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .onChange(of: chatVM.messages.count) { _, _ in
                    if let lastId = chatVM.messages.reversed().last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }

            // Input
            HStack(spacing: AppTheme.Spacing.xs) {
                TextField("メッセージを入力...", text: $text)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(AppTheme.Colors.surfaceVariant)
                    )
                    .foregroundColor(AppTheme.Colors.primary)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.Colors.secondary : .white)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(AppTheme.Colors.accent)
                    )
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.bottom, 70)
            .background(AppTheme.Colors.surface)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatVM.subscribeMessages(chatId: chatId)
            if let uid = authVM.user?.uid {
                chatVM.markAsRead(chatId: chatId, uid: uid)
            }
            Task {
                let info = await ChatService.shared.getParticipantInfo(uid: otherUserUid)
                otherPhotoURL = info.photoURL
            }
        }
        .onDisappear { chatVM.unsubscribeMessages() }
    }

    @ViewBuilder
    private func messageBubble(_ message: Message) -> some View {
        let isMine = message.senderUid == authVM.user?.uid

        if message.type == .alarm_notification {
            HStack(spacing: 4) {
                Image(systemName: "alarm")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.accent)
                Text(message.text)
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .italic()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.xs)
        } else if isMine {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.text)
                        .font(.system(size: AppTheme.FontSize.md))
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .fill(AppTheme.accentGradient)
                        )
                    Text(TimeUtils.formatHHmm(message.createdDate))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                }
            }
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                AvatarView(name: otherUserName, photoURL: otherPhotoURL, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.text)
                        .font(.system(size: AppTheme.FontSize.md))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .fill(AppTheme.Colors.surface)
                        )
                    Text(TimeUtils.formatHHmm(message.createdDate))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                }
                Spacer()
            }
        }
    }

    private func sendMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSending, let user = authVM.user else { return }
        isSending = true
        text = ""
        chatVM.sendMessage(chatId: chatId, senderUid: user.uid, text: trimmed)
        let bodyText = String(trimmed.prefix(50))
        Task {
            try? await NotificationHistoryService.shared.create(
                recipientUid: otherUserUid,
                type: .message,
                title: "@\(user.username) からメッセージ",
                body: bodyText,
                senderUid: user.uid,
                senderName: user.displayName,
                relatedId: chatId
            )
        }
        isSending = false
    }
}

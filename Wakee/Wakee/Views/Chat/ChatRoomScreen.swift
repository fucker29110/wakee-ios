import SwiftUI

struct ChatRoomScreen: View {
    let chatId: String
    let otherUserName: String
    let otherUserUid: String
    let chat: Chat?
    let initialGroupName: String?

    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var chatVM = ChatViewModel()
    @State private var text = ""
    @State private var isSending = false
    @State private var otherPhotoURL: String?
    @State private var showGroupSettings = false
    @State private var groupParticipants: [String: (displayName: String, photoURL: String?)] = [:]
    @FocusState private var isInputFocused: Bool

    // 1-to-1 chat init
    init(chatId: String, otherUserName: String, otherUserUid: String) {
        self.chatId = chatId
        self.otherUserName = otherUserName
        self.otherUserUid = otherUserUid
        self.chat = nil
        self.initialGroupName = nil
    }

    // Group chat init
    init(chatId: String, chat: Chat, groupName: String) {
        self.chatId = chatId
        self.otherUserName = groupName
        self.otherUserUid = ""
        self.chat = chat
        self.initialGroupName = groupName
    }

    private var isGroupChat: Bool {
        chat?.isGroup == true
    }

    private var navigationTitleText: String {
        if isGroupChat {
            return initialGroupName ?? LanguageManager.shared.l("group.default_name")
        }
        return otherUserName
    }

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
                .onChange(of: isInputFocused) { _, focused in
                    if focused, let lastId = chatVM.messages.reversed().last?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }
            }

            // Input
            HStack(spacing: AppTheme.Spacing.xs) {
                TextField(lang.l("chat.input"), text: $text)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(AppTheme.Colors.surfaceVariant)
                    )
                    .foregroundColor(AppTheme.Colors.primary)
                    .focused($isInputFocused)
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
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isGroupChat {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGroupSettings = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupSettings) {
            if let chat {
                GroupSettingsSheet(chatId: chatId, chat: chat, participantMap: groupParticipants)
            }
        }
        .onAppear {
            chatVM.subscribeMessages(chatId: chatId)
            if let uid = authVM.user?.uid {
                chatVM.markAsRead(chatId: chatId, uid: uid)
            }
            if isGroupChat {
                loadGroupParticipants()
            } else {
                Task {
                    let info = await ChatService.shared.getParticipantInfo(uid: otherUserUid)
                    otherPhotoURL = info.photoURL
                }
            }
        }
        .onDisappear { chatVM.unsubscribeMessages() }
    }

    private func loadGroupParticipants() {
        guard let chat else { return }
        Task {
            for uid in chat.users {
                let info = await ChatService.shared.getParticipantInfo(uid: uid)
                await MainActor.run {
                    groupParticipants[uid] = info
                }
            }
        }
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
            let senderName = isGroupChat
                ? (groupParticipants[message.senderUid]?.displayName ?? message.senderUid)
                : otherUserName
            let senderPhoto = isGroupChat
                ? groupParticipants[message.senderUid]?.photoURL
                : otherPhotoURL
            let senderUid = isGroupChat ? message.senderUid : otherUserUid

            HStack(alignment: .bottom, spacing: 6) {
                NavigationLink(destination: FriendProfileScreen(uid: senderUid)) {
                    AvatarView(name: senderName, photoURL: senderPhoto, size: 28)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    if isGroupChat {
                        Text(senderName)
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
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

        if isGroupChat {
            let bodyText = String(trimmed.prefix(50))
            let groupTitle = initialGroupName ?? LanguageManager.shared.l("group.default_name")
            guard let chat else { isSending = false; return }
            Task {
                for recipientUid in chat.users where recipientUid != user.uid {
                    try? await NotificationHistoryService.shared.create(
                        recipientUid: recipientUid,
                        type: .message,
                        title: lang.l("chat.group_message_from", args: user.username, groupTitle),
                        body: bodyText,
                        senderUid: user.uid,
                        senderName: user.displayName,
                        relatedId: chatId,
                        titleKey: "chat.group_message_from",
                        titleArgs: [user.username, groupTitle]
                    )
                }
            }
        } else {
            let bodyText = String(trimmed.prefix(50))
            Task {
                try? await NotificationHistoryService.shared.create(
                    recipientUid: otherUserUid,
                    type: .message,
                    title: lang.l("chat.message_from", args: user.username),
                    body: bodyText,
                    senderUid: user.uid,
                    senderName: user.displayName,
                    relatedId: chatId,
                    titleKey: "chat.message_from",
                    titleArgs: [user.username]
                )
            }
        }
        isSending = false
    }
}

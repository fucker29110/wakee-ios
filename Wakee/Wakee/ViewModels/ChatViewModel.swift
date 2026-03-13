import Foundation
import FirebaseFirestore

@Observable
final class ChatViewModel {
    var chats: [Chat] = []
    var messages: [Message] = []
    var participantMap: [String: (displayName: String, photoURL: String?)] = [:]
    var isLoading = true
    var sendError: String?

    private var chatsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var participantTask: Task<Void, Never>?

    deinit {
        unsubscribeChats()
        unsubscribeMessages()
        participantTask?.cancel()
    }

    func subscribeChats(uid: String) {
        chatsListener?.remove()
        chatsListener = ChatService.shared.subscribeChats(uid: uid) { [weak self] chats in
            guard let self else { return }
            self.chats = chats
            self.isLoading = false
            self.participantTask?.cancel()
            self.participantTask = Task { [weak self] in
                guard let self else { return }
                let otherUids = chats.compactMap { $0.otherUserId(myUid: uid) }
                for uid in Set(otherUids) {
                    if self.participantMap[uid] == nil {
                        let info = await ChatService.shared.getParticipantInfo(uid: uid)
                        await MainActor.run { [weak self] in self?.participantMap[uid] = info }
                    }
                }
            }
        }
    }

    func subscribeMessages(chatId: String) {
        messagesListener?.remove()
        messagesListener = ChatService.shared.subscribeMessages(chatId: chatId) { [weak self] messages in
            self?.messages = messages
        }
    }

    func unsubscribeChats() {
        chatsListener?.remove()
        chatsListener = nil
    }

    func unsubscribeMessages() {
        messagesListener?.remove()
        messagesListener = nil
    }

    func sendMessage(chatId: String, senderUid: String, text: String) {
        Task { @MainActor in
            do {
                try await ChatService.shared.sendMessage(chatId: chatId, senderUid: senderUid, text: text)
                sendError = nil
            } catch {
                sendError = "メッセージの送信に失敗しました"
                print("Send message error: \(error)")
            }
        }
    }

    func markAsRead(chatId: String, uid: String) {
        Task {
            try? await ChatService.shared.markAsRead(chatId: chatId, uid: uid)
        }
    }
}

import Foundation
import FirebaseFirestore

@Observable
final class ChatViewModel {
    var chats: [Chat] = []
    var messages: [Message] = []
    var participantMap: [String: (displayName: String, photoURL: String?)] = [:]
    var isLoading = true

    private var chatsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

    func subscribeChats(uid: String) {
        chatsListener?.remove()
        chatsListener = ChatService.shared.subscribeChats(uid: uid) { [weak self] chats in
            guard let self else { return }
            self.chats = chats
            self.isLoading = false
            Task {
                let otherUids = chats.compactMap { $0.otherUserId(myUid: uid) }
                for uid in Set(otherUids) {
                    if self.participantMap[uid] == nil {
                        let info = await ChatService.shared.getParticipantInfo(uid: uid)
                        await MainActor.run { self.participantMap[uid] = info }
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
        Task {
            try? await ChatService.shared.sendMessage(chatId: chatId, senderUid: senderUid, text: text)
        }
    }

    func markAsRead(chatId: String, uid: String) {
        Task {
            try? await ChatService.shared.markAsRead(chatId: chatId, uid: uid)
        }
    }
}

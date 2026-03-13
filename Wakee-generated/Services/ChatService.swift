import Foundation
import FirebaseFirestore

final class ChatService {
    static let shared = ChatService()
    private let db = Firestore.firestore()
    private var participantCache: [String: (displayName: String, photoURL: String?)] = [:]
    private init() {}

    static func chatId(uid1: String, uid2: String) -> String {
        let sorted = [uid1, uid2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    func getOrCreateChat(uid1: String, uid2: String) async throws -> String {
        let chatId = Self.chatId(uid1: uid1, uid2: uid2)
        let chatRef = db.collection("chats").document(chatId)
        let snap = try await chatRef.getDocument()
        if snap.exists { return chatId }

        let sorted = [uid1, uid2].sorted()
        try await chatRef.setData([
            "users": sorted,
            "userMap": [sorted[0]: true, sorted[1]: true],
            "lastMessage": "",
            "lastMessageAt": FieldValue.serverTimestamp(),
            "unreadCount": [sorted[0]: 0, sorted[1]: 0]
        ])
        return chatId
    }

    func sendMessage(chatId: String, senderUid: String, text: String, type: MessageType = .text) async throws {
        try await db.collection("chats").document(chatId).collection("messages").addDocument(data: [
            "senderUid": senderUid,
            "text": text,
            "type": type.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
        let chatRef = db.collection("chats").document(chatId)
        let snap = try await chatRef.getDocument()
        guard let data = snap.data(),
              let users = data["users"] as? [String] else { return }
        guard let otherUid = users.first(where: { $0 != senderUid }) else { return }
        try await chatRef.updateData([
            "lastMessage": text,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "unreadCount.\(otherUid)": FieldValue.increment(Int64(1))
        ])
    }

    func markAsRead(chatId: String, uid: String) async throws {
        try await db.collection("chats").document(chatId).updateData([
            "unreadCount.\(uid)": 0
        ])
    }

    func subscribeChats(uid: String, onUpdate: @escaping ([Chat]) -> Void) -> ListenerRegistration {
        return db.collection("chats")
            .whereField("userMap.\(uid)", isEqualTo: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let chats: [Chat] = docs.compactMap { try? $0.data(as: Chat.self) }
                let sorted = chats.sorted { $0.lastMessageDate > $1.lastMessageDate }
                onUpdate(sorted)
            }
    }

    func subscribeMessages(chatId: String, onUpdate: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("chats").document(chatId).collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let messages: [Message] = docs.compactMap { try? $0.data(as: Message.self) }
                onUpdate(messages)
            }
    }

    func getParticipantInfo(uid: String) async -> (displayName: String, photoURL: String?) {
        if let cached = participantCache[uid] { return cached }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            guard let data = snap.data() else { return (uid, nil) }
            let info = (
                displayName: data["displayName"] as? String ?? uid,
                photoURL: data["photoURL"] as? String
            )
            participantCache[uid] = info
            return info
        } catch {
            return (uid, nil)
        }
    }
}

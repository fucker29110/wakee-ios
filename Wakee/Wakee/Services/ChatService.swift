import Foundation
import FirebaseFirestore

final class ChatService {
    static let shared = ChatService()
    private let db = Firestore.firestore()
    private var participantCache: NSCache<NSString, ParticipantCacheEntry> = {
        let cache = NSCache<NSString, ParticipantCacheEntry>()
        cache.countLimit = 50
        return cache
    }()
    private init() {}

    class ParticipantCacheEntry: NSObject {
        let displayName: String
        let photoURL: String?
        init(displayName: String, photoURL: String?) {
            self.displayName = displayName
            self.photoURL = photoURL
        }
    }

    static func chatId(uid1: String, uid2: String) -> String {
        let sorted = [uid1, uid2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    func getOrCreateChat(uid1: String, uid2: String) async throws -> String {
        let chatId = Self.chatId(uid1: uid1, uid2: uid2)
        let chatRef = db.collection("chats").document(chatId)

        // Try to read first — if the document doesn't exist,
        // Firestore rules deny the read (resource.data is nil),
        // so we catch the error and fall through to create.
        do {
            let snap = try await chatRef.getDocument()
            if snap.exists { return chatId }
        } catch {
            // Permission denied likely means doc doesn't exist yet
        }

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
            .whereField("users", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ChatService] subscribeChats error: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                let chats: [Chat] = docs.compactMap { try? $0.data(as: Chat.self) }
                onUpdate(chats)
            }
    }

    func subscribeMessages(chatId: String, onUpdate: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("chats").document(chatId).collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ChatService] subscribeMessages error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                guard let docs = snapshot?.documents else { onUpdate([]); return }
                let messages: [Message] = docs.compactMap { try? $0.data(as: Message.self) }
                onUpdate(messages)
            }
    }

    func getParticipantInfo(uid: String) async -> (displayName: String, photoURL: String?) {
        if let cached = participantCache.object(forKey: uid as NSString) {
            return (cached.displayName, cached.photoURL)
        }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            guard let data = snap.data() else { return (uid, nil) }
            let displayName = data["displayName"] as? String ?? uid
            let photoURL = data["photoURL"] as? String
            participantCache.setObject(
                ParticipantCacheEntry(displayName: displayName, photoURL: photoURL),
                forKey: uid as NSString
            )
            return (displayName, photoURL)
        } catch {
            return (uid, nil)
        }
    }
}

import Foundation
import FirebaseFirestore

struct Chat: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var users: [String]
    var userMap: [String: Bool]
    var lastMessage: String
    var lastMessageAt: Timestamp?
    var unreadCount: [String: Int]

    var lastMessageDate: Date {
        lastMessageAt?.dateValue() ?? Date.distantPast
    }

    func unreadFor(uid: String) -> Int {
        unreadCount[uid] ?? 0
    }

    func otherUserId(myUid: String) -> String? {
        users.first { $0 != myUid }
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case users, userMap, lastMessage, lastMessageAt, unreadCount
    }
}

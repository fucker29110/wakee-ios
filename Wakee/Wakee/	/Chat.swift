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
    var isGroup: Bool?
    var groupName: String?
    var createdBy: String?
    var groupImageURL: String?

    var lastMessageDate: Date {
        lastMessageAt?.dateValue() ?? Date.distantPast
    }

    func unreadFor(uid: String) -> Int {
        unreadCount[uid] ?? 0
    }

    func otherUserId(myUid: String) -> String? {
        users.first { $0 != myUid }
    }

    func otherUserIds(myUid: String) -> [String] {
        users.filter { $0 != myUid }
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case users, userMap, lastMessage, lastMessageAt, unreadCount
        case isGroup, groupName, createdBy, groupImageURL
    }
}

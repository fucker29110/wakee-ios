import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case alarm_received
    case friend_request
    case friend_accepted
}

struct AppNotification: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var type: NotificationType
    var title: String
    var body: String
    var senderUid: String
    var senderName: String
    var relatedId: String?
    var read: Bool
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case type, title, body, senderUid, senderName, relatedId, read, createdAt
    }
}

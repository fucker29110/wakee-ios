import Foundation
import FirebaseFirestore

enum MessageType: String, Codable {
    case text
    case alarm_notification
}

struct Message: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var senderUid: String
    var text: String
    var type: MessageType
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case senderUid, text, type, createdAt
    }
}

import Foundation
import FirebaseFirestore

enum ActivityType: String, Codable {
    case sent
    case received_wakeup
    case achieved
    case rejected
    case snoozed
    case repost
}

struct Activity: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var type: ActivityType
    var actorUid: String
    var targetUid: String?
    var relatedEventId: String?
    var time: String
    var streak: Int?
    var message: String?
    var snoozeCount: Int?
    var displayMessage: String?
    var visibility: [String]
    var repostSourceId: String?
    var repostComment: String?
    var commentCount: Int?
    var lastCommentAt: Timestamp?
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case type, actorUid, targetUid, relatedEventId, time
        case streak, message, snoozeCount, displayMessage, visibility
        case repostSourceId, repostComment, commentCount, lastCommentAt, createdAt
    }
}

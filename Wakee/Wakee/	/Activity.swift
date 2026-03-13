	import Foundation
import FirebaseFirestore

enum ActivityType: String, Codable {
    case sent
    case received_wakeup
    case achieved
    case rejected
    case snoozed
    case repost

    var icon: String {
        switch self {
        case .achieved: return "sun.max.fill"
        case .rejected: return "moon.zzz.fill"
        case .snoozed: return "clock.fill"
        case .sent: return "alarm.fill"
        case .received_wakeup: return "bell.fill"
        case .repost: return "arrow.2.squarepath"
        }
    }

    var label: String {
        switch self {
        case .achieved: return "起きた!"
        case .rejected: return "二度寝した..."
        case .snoozed: return "スヌーズした"
        case .sent: return "アラームを送った"
        case .received_wakeup: return "アラームを受け取った"
        case .repost: return "リポストした"
        }
    }
}

struct Activity: Identifiable, Codable, Hashable {
    static func == (lhs: Activity, rhs: Activity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var type: ActivityType
    var actorUid: String
    var targetUid: String?
    var relatedEventId: String?
    var time: String
    var message: String?
    var audioURL: String?
    var snoozeCount: Int?
    var displayMessage: String?
    var visibility: [String]
    var repostSourceId: String?
    var repostComment: String?
    var isPrivate: Bool?
    var commentCount: Int?
    var likeCount: Int?
    var likedBy: [String]?
    var lastCommentAt: Timestamp?
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    var feedLabel: String { "が" + type.label }
    var feedIcon: String { type.icon }

    enum CodingKeys: String, CodingKey {
        case docID
        case type, actorUid, targetUid, relatedEventId, time
        case message, audioURL, snoozeCount, displayMessage, visibility
        case isPrivate
        case repostSourceId, repostComment, commentCount, likeCount, likedBy, lastCommentAt, createdAt
    }
}

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
        let lang = LanguageManager.shared
        switch self {
        case .achieved: return lang.l("activity.achieved")
        case .rejected: return lang.l("activity.rejected")
        case .snoozed: return lang.l("activity.snoozed")
        case .sent: return lang.l("activity.sent")
        case .received_wakeup: return lang.l("activity.received")
        case .repost: return lang.l("activity.repost")
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

    var feedLabel: String { type.label }
    var feedIcon: String { type.icon }

    enum CodingKeys: String, CodingKey {
        case docID
        case type, actorUid, targetUid, relatedEventId, time
        case message, audioURL, snoozeCount, displayMessage, visibility
        case isPrivate
        case repostSourceId, repostComment, commentCount, likeCount, likedBy, lastCommentAt, createdAt
    }
}

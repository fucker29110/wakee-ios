import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case alarm_received
    case friend_request
    case friend_accepted
    case comment
    case repost
    case like
    case message
}

struct AppNotification: Identifiable, Codable, Equatable {
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool { lhs.id == rhs.id && lhs.read == rhs.read }
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var type: NotificationType
    var title: String
    var body: String
    var senderUid: String
    var senderName: String
    var relatedId: String?
    var read: Bool
    var titleKey: String?
    var titleArgs: [String]?
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    /// ローカライズ済みタイトル（titleKey があればそちらを優先）
    var localizedTitle: String {
        if let key = titleKey {
            let lang = LanguageManager.shared
            if let args = titleArgs, !args.isEmpty {
                return String(format: lang.l(key), arguments: args)
            }
            return lang.l(key)
        }
        return title
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case type, title, body, senderUid, senderName, relatedId, read, titleKey, titleArgs, createdAt
    }
}

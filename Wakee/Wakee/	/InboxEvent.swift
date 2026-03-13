import Foundation
import FirebaseFirestore

/// 将来の繰り返しアラーム機能用に残す
enum WeekDay: String, Codable, CaseIterable {
    case Mon, Tue, Wed, Thu, Fri, Sat, Sun
}

enum InboxStatus: String, Codable {
    case pending, scheduled, rung, dismissed, snoozed, ignored
}

struct InboxEvent: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var senderUid: String
    var senderName: String
    var time: String
    var label: String
    var message: String
    var `repeat`: [WeekDay]
    var snoozeMin: Int
    var status: InboxStatus
    var isPrivate: Bool?
    var audioURL: String?
    var scheduledDate: Timestamp?
    @ServerTimestamp var createdAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case docID
        case senderUid, senderName, time, label, message
        case `repeat`, snoozeMin, status, isPrivate, audioURL, scheduledDate, createdAt
    }
}

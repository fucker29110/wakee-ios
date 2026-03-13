import Foundation
import FirebaseFirestore

enum WeekDay: String, Codable, CaseIterable {
    case Mon, Tue, Wed, Thu, Fri, Sat, Sun
}

enum InboxStatus: String, Codable {
    case pending, scheduled, rung, dismissed, snoozed
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
    var audioURL: String?
    var scheduledDate: Timestamp?
    @ServerTimestamp var createdAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case docID
        case senderUid, senderName, time, label, message
        case `repeat`, snoozeMin, status, audioURL, scheduledDate, createdAt
    }
}

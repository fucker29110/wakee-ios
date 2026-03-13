import Foundation
import FirebaseFirestore

enum FollowRequestStatus: String, Codable {
    case pending, accepted, rejected
}

struct FollowRequest: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var fromUid: String
    var toUid: String
    var fromName: String
    var status: FollowRequestStatus
    @ServerTimestamp var createdAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case docID
        case fromUid, toUid, fromName, status, createdAt
    }
}

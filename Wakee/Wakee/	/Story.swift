import Foundation
import FirebaseFirestore

struct Story: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var authorUid: String
    var text: String
    var readBy: [String]
    var createdAt: Timestamp?
    var expiresAt: Timestamp?

    var isExpired: Bool {
        guard let expires = expiresAt else { return true }
        return expires.dateValue() < Date()
    }

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case authorUid, text, readBy, createdAt, expiresAt
    }
}

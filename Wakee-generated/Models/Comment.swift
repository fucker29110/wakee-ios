import Foundation
import FirebaseFirestore

enum VisibilityBasis: String, Codable {
    case actor_friends
    case target_friends
}

struct Comment: Identifiable, Codable {
    @DocumentID var docID: String?
    var id: String { docID ?? UUID().uuidString }
    var authorId: String
    var text: String
    var visibilityBasis: VisibilityBasis
    @ServerTimestamp var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case docID
        case authorId, text, visibilityBasis, createdAt
    }
}

import Foundation
import FirebaseFirestore

final class CommentService {
    static let shared = CommentService()
    private let db = Firestore.firestore()
    private init() {}

    func addComment(
        activityId: String,
        authorId: String,
        text: String,
        visibilityBasis: VisibilityBasis
    ) async throws {
        try await db.collection("activities").document(activityId)
            .collection("comments").addDocument(data: [
                "authorId": authorId,
                "text": text,
                "visibilityBasis": visibilityBasis.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
        try await db.collection("activities").document(activityId).updateData([
            "commentCount": FieldValue.increment(Int64(1)),
            "lastCommentAt": FieldValue.serverTimestamp()
        ])
    }

    func subscribeComments(activityId: String, onUpdate: @escaping ([Comment]) -> Void) -> ListenerRegistration {
        return db.collection("activities").document(activityId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let comments: [Comment] = docs.compactMap { try? $0.data(as: Comment.self) }
                onUpdate(comments)
            }
    }
}

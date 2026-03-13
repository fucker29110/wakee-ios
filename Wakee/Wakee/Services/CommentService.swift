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
        visibilityBasis: VisibilityBasis,
        senderUsername: String,
        senderName: String,
        activityActorUid: String
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

        if authorId != activityActorUid {
            try? await NotificationHistoryService.shared.create(
                recipientUid: activityActorUid,
                type: .comment,
                title: "@\(senderUsername) がコメントしました",
                body: text,
                senderUid: authorId,
                senderName: senderName,
                relatedId: activityId
            )
        }
    }

    func subscribeComments(activityId: String, onUpdate: @escaping ([Comment]) -> Void) -> ListenerRegistration {
        return db.collection("activities").document(activityId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommentService] subscribeComments error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                guard let docs = snapshot?.documents else { onUpdate([]); return }
                let comments: [Comment] = docs.compactMap { try? $0.data(as: Comment.self) }
                onUpdate(comments)
            }
    }
}

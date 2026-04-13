import Foundation
import FirebaseFirestore

final class LikeService {
    static let shared = LikeService()
    private let db = Firestore.firestore()
    private init() {}

    /// いいねをトグル（トランザクションで安全に追加/解除）
    func toggleLike(activityId: String, userId: String, senderUsername: String, senderName: String) async throws {
        let activityRef = db.collection("activities").document(activityId)
        var actorUid: String?
        var liked = false

        try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(activityRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            actorUid = snapshot.data()?["actorUid"] as? String
            let likedBy = snapshot.data()?["likedBy"] as? [String] ?? []
            let alreadyLiked = likedBy.contains(userId)

            if alreadyLiked {
                transaction.updateData([
                    "likedBy": FieldValue.arrayRemove([userId]),
                    "likeCount": FieldValue.increment(Int64(-1))
                ], forDocument: activityRef)
            } else {
                liked = true
                transaction.updateData([
                    "likedBy": FieldValue.arrayUnion([userId]),
                    "likeCount": FieldValue.increment(Int64(1))
                ], forDocument: activityRef)
            }

            return nil
        }

        if liked, let actorUid, actorUid != userId {
            try? await NotificationHistoryService.shared.create(
                recipientUid: actorUid,
                type: .like,
                title: LanguageManager.shared.l("push.liked", args: senderUsername),
                body: "",
                senderUid: userId,
                senderName: senderName,
                relatedId: activityId,
                titleKey: "push.liked",
                titleArgs: [senderUsername]
            )
        }
    }
}

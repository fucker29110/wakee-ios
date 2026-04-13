import FirebaseFirestore

final class ReportService {
    static let shared = ReportService()
    private let db = Firestore.firestore()

    func submitReport(
        reporterId: String,
        targetUserId: String,
        postId: String?,
        reason: String
    ) async throws {
        let data: [String: Any] = [
            "reporterId": reporterId,
            "targetUserId": targetUserId,
            "postId": postId ?? "",
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ]
        try await db.collection("reports").addDocument(data: data)
    }
}

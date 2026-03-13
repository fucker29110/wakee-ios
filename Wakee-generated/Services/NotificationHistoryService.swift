import Foundation
import FirebaseFirestore

final class NotificationHistoryService {
    static let shared = NotificationHistoryService()
    private let db = Firestore.firestore()
    private init() {}

    func create(
        recipientUid: String,
        type: NotificationType,
        title: String,
        body: String,
        senderUid: String,
        senderName: String,
        relatedId: String? = nil
    ) async throws {
        try await db.collection("users").document(recipientUid)
            .collection("notifications").addDocument(data: [
                "type": type.rawValue,
                "title": title,
                "body": body,
                "senderUid": senderUid,
                "senderName": senderName,
                "relatedId": relatedId as Any,
                "read": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    func subscribe(uid: String, onUpdate: @escaping ([AppNotification]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(uid).collection("notifications")
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let notifications: [AppNotification] = docs.compactMap { try? $0.data(as: AppNotification.self) }
                let sorted = notifications.sorted { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                onUpdate(sorted)
            }
    }

    func subscribeUnreadCount(uid: String, onUpdate: @escaping (Int) -> Void) -> ListenerRegistration {
        return db.collection("users").document(uid).collection("notifications")
            .whereField("read", isEqualTo: false)
            .addSnapshotListener { snapshot, _ in
                onUpdate(snapshot?.documents.count ?? 0)
            }
    }

    func markAllAsRead(uid: String) async throws {
        let snap = try await db.collection("users").document(uid).collection("notifications")
            .whereField("read", isEqualTo: false)
            .getDocuments()
        guard !snap.documents.isEmpty else { return }
        let batch = db.batch()
        for doc in snap.documents {
            batch.updateData(["read": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }
}

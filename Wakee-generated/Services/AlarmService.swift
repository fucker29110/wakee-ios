import Foundation
import FirebaseFirestore

final class AlarmService {
    static let shared = AlarmService()
    private let db = Firestore.firestore()
    private init() {}

    func sendAlarm(
        senderUid: String,
        senderName: String,
        receiverUid: String,
        time: String,
        label: String,
        message: String,
        snoozeMin: Int,
        audioURL: String? = nil
    ) async throws -> String {
        let alarmDate = TimeUtils.nextAlarmDate(time: time)
        let data: [String: Any] = [
            "senderUid": senderUid,
            "senderName": senderName,
            "time": time,
            "label": label.isEmpty ? "\(senderName)からのアラーム" : label,
            "message": message,
            "repeat": [String](),
            "snoozeMin": snoozeMin,
            "audioURL": audioURL as Any,
            "status": InboxStatus.pending.rawValue,
            "scheduledDate": Timestamp(date: alarmDate),
            "createdAt": FieldValue.serverTimestamp()
        ]
        let ref = try await db.collection("users").document(receiverUid)
            .collection("inbox").addDocument(data: data)
        return ref.documentID
    }

    func updateInboxStatus(receiverUid: String, eventId: String, status: InboxStatus) async throws {
        try await db.collection("users").document(receiverUid)
            .collection("inbox").document(eventId)
            .updateData(["status": status.rawValue])
    }

    func snoozeAlarm(receiverUid: String, event: InboxEvent, snoozeMin: Int) async throws {
        let snoozeDate = Date().addingTimeInterval(TimeInterval(snoozeMin * 60))
        try await db.collection("users").document(receiverUid)
            .collection("inbox").document(event.id)
            .updateData([
                "status": InboxStatus.snoozed.rawValue,
                "scheduledDate": Timestamp(date: snoozeDate)
            ])
    }

    func subscribeInbox(uid: String, onUpdate: @escaping ([InboxEvent]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(uid).collection("inbox")
            .whereField("status", in: ["pending", "scheduled", "snoozed"])
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                let events: [InboxEvent] = docs.compactMap { doc in
                    var event = try? doc.data(as: InboxEvent.self)
                    return event
                }
                let sorted = events.sorted { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                onUpdate(sorted)
            }
    }
}

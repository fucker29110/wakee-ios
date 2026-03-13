import Foundation
import FirebaseFirestore

final class StoryService {
    static let shared = StoryService()
    private let db = Firestore.firestore()
    private static let twelveHoursMs: Int64 = 12 * 60 * 60 * 1000
    private init() {}

    func postStory(uid: String, text: String) async throws {
        let existing = try await db.collection("stories")
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()
        let now = Date()
        let activeDocs = existing.documents.filter { doc in
            guard let expires = (doc.data()["expiresAt"] as? Timestamp)?.dateValue() else { return false }
            return expires > now
        }
        for doc in activeDocs {
            try await db.collection("stories").document(doc.documentID).delete()
        }
        let createdAt = Timestamp(date: now)
        let expiresAt = Timestamp(date: now.addingTimeInterval(12 * 60 * 60))
        try await db.collection("stories").addDocument(data: [
            "authorUid": uid,
            "text": text,
            "readBy": [String](),
            "createdAt": createdAt,
            "expiresAt": expiresAt
        ])
    }

    func subscribeActiveStories(friendUids: [String], onUpdate: @escaping ([Story]) -> Void) -> [ListenerRegistration] {
        guard !friendUids.isEmpty else { onUpdate([]); return [] }
        let chunks = stride(from: 0, to: friendUids.count, by: 30).map {
            Array(friendUids[$0..<min($0 + 30, friendUids.count)])
        }
        var allStories: [String: [Story]] = [:]
        var listeners = [ListenerRegistration]()

        for chunk in chunks {
            let key = chunk.joined(separator: ",")
            let listener = db.collection("stories")
                .whereField("authorUid", in: chunk)
                .addSnapshotListener { snapshot, _ in
                    guard let docs = snapshot?.documents else { return }
                    let now = Date()
                    let stories: [Story] = docs.compactMap { doc -> Story? in
                        guard let story = try? doc.data(as: Story.self),
                              !story.isExpired else { return nil }
                        return story
                    }
                    allStories[key] = stories
                    let merged = allStories.values.flatMap { $0 }
                        .sorted { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                    onUpdate(merged)
                }
            listeners.append(listener)
        }
        return listeners
    }

    func markAsRead(storyId: String, uid: String) async throws {
        try await db.collection("stories").document(storyId).updateData([
            "readBy": FieldValue.arrayUnion([uid])
        ])
    }

    func deleteStory(storyId: String) async throws {
        try await db.collection("stories").document(storyId).delete()
    }

    func editStory(storyId: String, text: String) async throws {
        try await db.collection("stories").document(storyId).updateData(["text": text])
    }

    func getMyActiveStory(uid: String) async throws -> Story? {
        let snap = try await db.collection("stories")
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()
        let now = Date()
        return snap.documents.compactMap { doc -> Story? in
            guard let story = try? doc.data(as: Story.self),
                  !story.isExpired else { return nil }
            return story
        }.first
    }
}

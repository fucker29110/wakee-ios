import Foundation
import FirebaseFirestore

final class FriendService {
    static let shared = FriendService()
    private let db = Firestore.firestore()
    private init() {}

    func searchByUsername(username: String, myUid: String) async throws -> [AppUser] {
        let snap = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased().trimmingCharacters(in: .whitespaces))
            .limit(to: 10)
            .getDocuments()
        return snap.documents.compactMap { doc -> AppUser? in
            guard doc.documentID != myUid else { return nil }
            let data = doc.data()
            return AppUser(
                uid: doc.documentID,
                displayName: data["displayName"] as? String ?? "",
                photoURL: data["photoURL"] as? String,
                username: data["username"] as? String ?? "",
                bio: data["bio"] as? String ?? "",
                location: data["location"] as? String ?? "",
                streak: data["streak"] as? Int ?? 0
            )
        }
    }

    func sendFollowRequest(fromUid: String, toUid: String, fromName: String) async throws -> String {
        let existing = try await db.collection("followRequests")
            .whereField("fromUid", isEqualTo: fromUid)
            .whereField("toUid", isEqualTo: toUid)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        if let existingDoc = existing.documents.first { return existingDoc.documentID }

        let ref = try await db.collection("followRequests").addDocument(data: [
            "fromUid": fromUid,
            "toUid": toUid,
            "fromName": fromName,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await NotificationHistoryService.shared.create(
            recipientUid: toUid,
            type: .friend_request,
            title: "フレンド申請",
            body: "\(fromName)さんからフレンド申請が届きました",
            senderUid: fromUid,
            senderName: fromName,
            relatedId: ref.documentID
        )
        return ref.documentID
    }

    func acceptRequest(requestId: String, fromUid: String, toUid: String) async throws {
        try await db.collection("followRequests").document(requestId).updateData(["status": "accepted"])
        let sorted = [fromUid, toUid].sorted()
        let friendshipId = "\(sorted[0])_\(sorted[1])"
        try await db.collection("friendships").document(friendshipId).setData([
            "users": sorted,
            "userMap": [sorted[0]: true, sorted[1]: true],
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)

        let acceptorSnap = try await db.collection("users").document(toUid).getDocument()
        let acceptorName = acceptorSnap.data()?["displayName"] as? String ?? "ユーザー"
        try await NotificationHistoryService.shared.create(
            recipientUid: fromUid,
            type: .friend_accepted,
            title: "フレンド承認",
            body: "\(acceptorName)さんがフレンド申請を承認しました",
            senderUid: toUid,
            senderName: acceptorName,
            relatedId: requestId
        )
    }

    func rejectRequest(requestId: String) async throws {
        try await db.collection("followRequests").document(requestId).updateData(["status": "rejected"])
    }

    func subscribeFriends(uid: String, onUpdate: @escaping ([AppUser]) -> Void) -> ListenerRegistration {
        return db.collection("friendships")
            .whereField("userMap.\(uid)", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { onUpdate([]); return }
                let friendUids = docs.compactMap { doc -> String? in
                    let users = doc.data()["users"] as? [String] ?? []
                    return users.first { $0 != uid }
                }
                if friendUids.isEmpty { onUpdate([]); return }
                Task {
                    let friends = await self.fetchUsers(uids: friendUids)
                    await MainActor.run { onUpdate(friends) }
                }
            }
    }

    func subscribeRequests(uid: String, onUpdate: @escaping ([FollowRequest]) -> Void) -> ListenerRegistration {
        return db.collection("followRequests")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { onUpdate([]); return }
                let requests: [FollowRequest] = docs.compactMap { try? $0.data(as: FollowRequest.self) }
                onUpdate(requests)
            }
    }

    func blockUser(myUid: String, targetUid: String) async throws {
        try await db.collection("users").document(myUid).updateData([
            "settings.blocked": FieldValue.arrayUnion([targetUid])
        ])
    }

    func checkFriendship(uid1: String, uid2: String) async throws -> Bool {
        let sorted = [uid1, uid2].sorted()
        let snap = try await db.collection("friendships").document("\(sorted[0])_\(sorted[1])").getDocument()
        return snap.exists
    }

    func checkSentRequest(fromUid: String, toUid: String) async throws -> String {
        let snap = try await db.collection("followRequests")
            .whereField("fromUid", isEqualTo: fromUid)
            .whereField("toUid", isEqualTo: toUid)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        return snap.documents.isEmpty ? "none" : "pending"
    }

    func getFriendUids(uid: String) async throws -> [String] {
        let snap = try await db.collection("friendships")
            .whereField("userMap.\(uid)", isEqualTo: true)
            .getDocuments()
        return snap.documents.compactMap { doc -> String? in
            let users = doc.data()["users"] as? [String] ?? []
            return users.first { $0 != uid }
        }
    }

    func getReceivedRequest(fromUid: String, toUid: String) async throws -> FollowRequest? {
        let snap = try await db.collection("followRequests")
            .whereField("fromUid", isEqualTo: fromUid)
            .whereField("toUid", isEqualTo: toUid)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { return nil }
        return try doc.data(as: FollowRequest.self)
    }

    func getUserByUid(_ uid: String) async throws -> AppUser? {
        let snap = try await db.collection("users").document(uid).getDocument()
        guard snap.exists, let data = snap.data() else { return nil }
        return AppUser(
            uid: snap.documentID,
            displayName: data["displayName"] as? String ?? "",
            photoURL: data["photoURL"] as? String,
            username: data["username"] as? String ?? "",
            bio: data["bio"] as? String ?? "",
            location: data["location"] as? String ?? "",
            streak: data["streak"] as? Int ?? 0
        )
    }

    private func fetchUsers(uids: [String]) async -> [AppUser] {
        await withTaskGroup(of: AppUser?.self) { group in
            for uid in uids {
                group.addTask { [weak self] in
                    try? await self?.getUserByUid(uid)
                }
            }
            var results = [AppUser]()
            for await user in group {
                if let user { results.append(user) }
            }
            return results
        }
    }
}

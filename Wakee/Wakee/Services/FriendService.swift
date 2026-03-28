import Foundation
import FirebaseFirestore

final class FriendService {
    static let shared = FriendService()
    private let db = Firestore.firestore()
    private init() {}

    func searchByUsername(username: String, myUid: String) async throws -> [AppUser] {
        let prefix = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty else { return [] }
        let end = prefix + "\u{f8ff}"
        let snap = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: prefix)
            .whereField("username", isLessThan: end)
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
                location: data["location"] as? String ?? ""
            )
        }
    }

    func sendFollowRequest(fromUid: String, toUid: String, fromName: String, fromUsername: String) async throws -> String {
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
            title: LanguageManager.shared.l("push.follow_request", args: fromUsername),
            body: "",
            senderUid: fromUid,
            senderName: fromName,
            relatedId: ref.documentID,
            titleKey: "push.follow_request",
            titleArgs: [fromUsername]
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
        let acceptorName = acceptorSnap.data()?["displayName"] as? String ?? LanguageManager.shared.l("common.user")
        let acceptorUsername = acceptorSnap.data()?["username"] as? String ?? ""
        try await NotificationHistoryService.shared.create(
            recipientUid: fromUid,
            type: .friend_accepted,
            title: LanguageManager.shared.l("push.follow_accepted", args: acceptorUsername),
            body: "",
            senderUid: toUid,
            senderName: acceptorName,
            relatedId: requestId,
            titleKey: "push.follow_accepted",
            titleArgs: [acceptorUsername]
        )
    }

    func rejectRequest(requestId: String) async throws {
        try await db.collection("followRequests").document(requestId).updateData(["status": "rejected"])
    }

    func subscribeFriends(uid: String, onUpdate: @escaping ([AppUser]) -> Void) -> ListenerRegistration {
        return db.collection("friendships")
            .whereField("userMap.\(uid)", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("[FriendService] subscribeFriends error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
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
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[FriendService] subscribeRequests error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                guard let docs = snapshot?.documents else { onUpdate([]); return }
                let requests: [FollowRequest] = docs.compactMap { try? $0.data(as: FollowRequest.self) }
                onUpdate(requests)
            }
    }

    func blockUser(myUid: String, targetUid: String) async throws {
        try await db.collection("users").document(myUid).updateData([
            "settings.blocked": FieldValue.arrayUnion([targetUid])
        ])
        try? await removeFriendship(uid1: myUid, uid2: targetUid)
    }

    func unblockUser(myUid: String, targetUid: String) async throws {
        try await db.collection("users").document(myUid).updateData([
            "settings.blocked": FieldValue.arrayRemove([targetUid])
        ])
    }

    func removeFriendship(uid1: String, uid2: String) async throws {
        let sorted = [uid1, uid2].sorted()
        let friendshipId = "\(sorted[0])_\(sorted[1])"
        try await db.collection("friendships").document(friendshipId).delete()
    }

    func checkFriendship(uid1: String, uid2: String) async throws -> Bool {
        let snap = try await db.collection("friendships")
            .whereField("userMap.\(uid1)", isEqualTo: true)
            .whereField("userMap.\(uid2)", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        return !snap.documents.isEmpty
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
            location: data["location"] as? String ?? ""
        )
    }

    /// おすすめ友達を取得（共通フレンドが多い順）
    func fetchSuggestions(uid: String) async throws -> [(user: AppUser, mutualCount: Int)] {
        // 自分のフレンドUID一覧
        let myFriendUids = try await getFriendUids(uid: uid)
        let myFriendSet = Set(myFriendUids)
        if myFriendSet.isEmpty { return [] }

        // フレンドのフレンド（＝候補）を集計
        var mutualCounts: [String: Int] = [:]
        for friendUid in myFriendUids {
            let fofUids = try await getFriendUids(uid: friendUid)
            for fof in fofUids {
                // 自分自身と既にフレンドの人は除外
                guard fof != uid, !myFriendSet.contains(fof) else { continue }
                mutualCounts[fof, default: 0] += 1
            }
        }

        // 共通フレンド多い順にソート、上位20件
        let sorted = mutualCounts.sorted { $0.value > $1.value }.prefix(20)
        let candidateUids = sorted.map(\.key)
        if candidateUids.isEmpty { return [] }

        let users = await fetchUsers(uids: candidateUids)
        let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.uid, $0) })

        return sorted.compactMap { uid, count in
            guard let user = userMap[uid] else { return nil }
            return (user: user, mutualCount: count)
        }
    }

    func getMutualFriends(myUid: String, otherUid: String) async throws -> [AppUser] {
        async let myFriendUids = getFriendUids(uid: myUid)
        async let otherFriendUids = getFriendUids(uid: otherUid)
        let mutualUids = Array(Set(try await myFriendUids).intersection(Set(try await otherFriendUids)))
        if mutualUids.isEmpty { return [] }
        return await fetchUsers(uids: mutualUids)
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

import Foundation
import FirebaseFirestore

final class ActivityService {
    static let shared = ActivityService()
    private let db = Firestore.firestore()
    private var userCache = NSCache<NSString, UserCacheEntry>()
    private init() {}

    // MARK: - Cache helper
    class UserCacheEntry: NSObject {
        let displayName: String
        let photoURL: String?
        let username: String
        init(displayName: String, photoURL: String?, username: String) {
            self.displayName = displayName
            self.photoURL = photoURL
            self.username = username
        }
    }

    struct UserInfo {
        let displayName: String
        let photoURL: String?
        let username: String
    }

    // MARK: - Record activity
    func record(
        type: ActivityType,
        actorUid: String,
        targetUid: String? = nil,
        relatedEventId: String? = nil,
        time: String,
        streak: Int? = nil,
        message: String? = nil,
        snoozeCount: Int? = nil,
        displayMessage: String? = nil,
        visibleTo: [String],
        repostSourceId: String? = nil,
        repostComment: String? = nil
    ) async throws {
        var data: [String: Any] = [
            "type": type.rawValue,
            "actorUid": actorUid,
            "targetUid": targetUid as Any,
            "relatedEventId": relatedEventId as Any,
            "time": time,
            "streak": streak as Any,
            "message": message as Any,
            "snoozeCount": snoozeCount as Any,
            "displayMessage": displayMessage as Any,
            "visibility": visibleTo,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let repostSourceId { data["repostSourceId"] = repostSourceId }
        if let repostComment { data["repostComment"] = repostComment }
        try await db.collection("activities").addDocument(data: data)
    }

    // MARK: - Subscribe feed
    func subscribeFeed(uid: String, onUpdate: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("activities")
            .whereField("visibility", arrayContains: uid)
            .limit(to: 30)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let activities: [Activity] = docs.compactMap { try? $0.data(as: Activity.self) }
                let sorted = activities.sorted { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                onUpdate(sorted)
            }
    }

    // MARK: - Subscribe my activities
    func subscribeMyActivities(uid: String, onUpdate: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("activities")
            .whereField("actorUid", isEqualTo: uid)
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let activities: [Activity] = docs.compactMap { try? $0.data(as: Activity.self) }
                let sorted = activities.sorted { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                onUpdate(sorted)
            }
    }

    // MARK: - Subscribe single activity
    func subscribeActivity(activityId: String, onUpdate: @escaping (Activity?) -> Void) -> ListenerRegistration {
        return db.collection("activities").document(activityId)
            .addSnapshotListener { snapshot, _ in
                guard let snap = snapshot, snap.exists else { onUpdate(nil); return }
                onUpdate(try? snap.data(as: Activity.self))
            }
    }

    // MARK: - Get activity
    func getActivity(activityId: String) async throws -> Activity? {
        let snap = try await db.collection("activities").document(activityId).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: Activity.self)
    }

    // MARK: - User info lookup with cache
    func getUsersForActivities(_ activities: [Activity]) async -> [String: UserInfo] {
        var allUids = Set<String>()
        for a in activities {
            allUids.insert(a.actorUid)
            if let target = a.targetUid { allUids.insert(target) }
        }
        return await getUserInfoByUids(Array(allUids))
    }

    func getUserInfoByUids(_ uids: [String]) async -> [String: UserInfo] {
        let unique = Array(Set(uids))
        var missing = [String]()
        var result = [String: UserInfo]()

        for uid in unique {
            if let cached = userCache.object(forKey: uid as NSString) {
                result[uid] = UserInfo(displayName: cached.displayName, photoURL: cached.photoURL, username: cached.username)
            } else {
                missing.append(uid)
            }
        }

        await withTaskGroup(of: (String, UserInfo?).self) { group in
            for uid in missing {
                group.addTask { [weak self] in
                    guard let self else { return (uid, nil) }
                    do {
                        let snap = try await self.db.collection("users").document(uid).getDocument()
                        guard let data = snap.data() else { return (uid, nil) }
                        let info = UserInfo(
                            displayName: data["displayName"] as? String ?? uid,
                            photoURL: data["photoURL"] as? String,
                            username: data["username"] as? String ?? ""
                        )
                        return (uid, info)
                    } catch {
                        return (uid, nil)
                    }
                }
            }
            for await (uid, info) in group {
                if let info {
                    result[uid] = info
                    userCache.setObject(
                        UserCacheEntry(displayName: info.displayName, photoURL: info.photoURL, username: info.username),
                        forKey: uid as NSString
                    )
                }
            }
        }
        return result
    }

    func getDisplayNames(_ uids: [String]) async -> [String: String] {
        let infos = await getUserInfoByUids(uids)
        return infos.mapValues { $0.displayName }
    }
}

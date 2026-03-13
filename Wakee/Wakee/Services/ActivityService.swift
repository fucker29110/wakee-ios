import Foundation
import FirebaseFirestore

final class ActivityService {
    static let shared = ActivityService()
    private let db = Firestore.firestore()
    private var userCache: NSCache<NSString, UserCacheEntry> = {
        let cache = NSCache<NSString, UserCacheEntry>()
        cache.countLimit = 100
        return cache
    }()
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
    @discardableResult
    func record(
        type: ActivityType,
        actorUid: String,
        targetUid: String? = nil,
        relatedEventId: String? = nil,
        time: String,
        message: String? = nil,
        audioURL: String? = nil,
        snoozeCount: Int? = nil,
        displayMessage: String? = nil,
        visibleTo: [String],
        repostSourceId: String? = nil,
        repostComment: String? = nil,
        isPrivate: Bool = false
    ) async throws -> String {
        var data: [String: Any] = [
            "type": type.rawValue,
            "actorUid": actorUid,
            "targetUid": targetUid as Any,
            "relatedEventId": relatedEventId as Any,
            "time": time,
            "message": message as Any,
            "audioURL": audioURL as Any,
            "snoozeCount": snoozeCount as Any,
            "displayMessage": displayMessage as Any,
            "visibility": visibleTo,
            "isPrivate": isPrivate,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let repostSourceId { data["repostSourceId"] = repostSourceId }
        if let repostComment { data["repostComment"] = repostComment }
        let ref = try await db.collection("activities").addDocument(data: data)
        return ref.documentID
    }

    func deleteActivity(activityId: String) async throws {
        try await db.collection("activities").document(activityId).delete()
    }

    // MARK: - Subscribe feed
    func subscribeFeed(uid: String, onUpdate: @escaping ([Activity]) -> Void) -> ListenerRegistration {
        return db.collection("activities")
            .whereField("visibility", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ActivityService] subscribeFeed error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                guard let docs = snapshot?.documents else { onUpdate([]); return }
                let activities: [Activity] = docs.compactMap { try? $0.data(as: Activity.self) }
                onUpdate(activities.filter { $0.isPrivate != true })
            }
    }

    // MARK: - Subscribe profile activities (dual-listener merge)
    func subscribeProfileActivities(uid: String, isOwnProfile: Bool, viewerUid: String, onUpdate: @escaping ([Activity]) -> Void) -> [ListenerRegistration] {
        var actorResults: [Activity] = []
        var targetResults: [Activity] = []
        var pendingMerge: DispatchWorkItem?

        func scheduleMerge() {
            pendingMerge?.cancel()
            let work = DispatchWorkItem {
                var merged: [String: Activity] = [:]
                for a in actorResults + targetResults { merged[a.id] = a }
                var list = Array(merged.values)
                if !isOwnProfile {
                    list = list.filter { $0.isPrivate != true }
                }
                list.sort { ($0.createdAt?.seconds ?? 0) > ($1.createdAt?.seconds ?? 0) }
                onUpdate(Array(list.prefix(30)))
            }
            pendingMerge = work
            DispatchQueue.main.async(execute: work)
        }

        // 自分のプロフィール: actorUid == myUid でセキュリティルール通過
        // 他人のプロフィール: visibility arrayContains viewerUid を追加してルール通過
        var queryA: Query = db.collection("activities")
            .whereField("actorUid", isEqualTo: uid)
        if !isOwnProfile {
            queryA = queryA.whereField("visibility", arrayContains: viewerUid)
        }
        let listenerA = queryA
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ActivityService] subscribeProfileActivities(actor) error: \(error.localizedDescription)")
                }
                actorResults = snapshot?.documents.compactMap { try? $0.data(as: Activity.self) } ?? []
                scheduleMerge()
            }

        var queryB: Query = db.collection("activities")
            .whereField("targetUid", isEqualTo: uid)
        if !isOwnProfile {
            queryB = queryB.whereField("visibility", arrayContains: viewerUid)
        }
        let listenerB = queryB
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ActivityService] subscribeProfileActivities(target) error: \(error.localizedDescription)")
                }
                targetResults = snapshot?.documents.compactMap { try? $0.data(as: Activity.self) } ?? []
                scheduleMerge()
            }

        return [listenerA, listenerB]
    }

    // MARK: - Subscribe single activity
    func subscribeActivity(activityId: String, onUpdate: @escaping (Activity?) -> Void) -> ListenerRegistration {
        return db.collection("activities").document(activityId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[ActivityService] subscribeActivity error: \(error.localizedDescription)")
                    onUpdate(nil)
                    return
                }
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

    // MARK: - Load repost source activities
    func loadSourceActivities(for activities: [Activity], existing: [String: Activity]) async -> [String: Activity] {
        let sourceIds = activities
            .filter { $0.type == .repost }
            .compactMap { $0.repostSourceId }
            .filter { existing[$0] == nil }
        guard !sourceIds.isEmpty else { return existing }
        var map = existing
        await withTaskGroup(of: (String, Activity?).self) { group in
            for id in sourceIds {
                group.addTask {
                    let activity = try? await ActivityService.shared.getActivity(activityId: id)
                    return (id, activity)
                }
            }
            for await (id, activity) in group {
                if let activity { map[id] = activity }
            }
        }
        return map
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

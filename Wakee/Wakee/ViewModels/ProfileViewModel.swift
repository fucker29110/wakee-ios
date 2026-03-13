import Foundation
import FirebaseFirestore

@Observable
final class ProfileViewModel {
    var activities: [Activity] = []
    var userMap: [String: ActivityService.UserInfo] = [:]
    var sourceActivities: [String: Activity] = [:]
    var isLoadingActivities = true
    var friendCount = 0

    private var activitiesListeners: [ListenerRegistration] = []
    private var friendsListener: ListenerRegistration?
    private var loadTask: Task<Void, Never>?
    private var refreshContinuation: CheckedContinuation<Void, Never>?
    private var subscribedIsOwnProfile = true
    private var subscribedUid = ""
    private var subscribedViewerUid = ""

    deinit {
        unsubscribe()
    }

    func subscribe(uid: String, isOwnProfile: Bool = true, viewerUid: String? = nil) {
        unsubscribe()
        subscribeFriendCount(uid: uid)
        subscribeActivities(uid: uid, isOwnProfile: isOwnProfile, viewerUid: viewerUid)
    }

    func subscribeFriendCount(uid: String) {
        friendsListener?.remove()
        friendsListener = FriendService.shared.subscribeFriends(uid: uid) { [weak self] friends in
            self?.friendCount = friends.count
        }
    }

    func subscribeActivities(uid: String, isOwnProfile: Bool = true, viewerUid: String? = nil) {
        activitiesListeners.forEach { $0.remove() }
        activitiesListeners.removeAll()
        loadTask?.cancel()
        loadTask = nil

        subscribedIsOwnProfile = isOwnProfile
        subscribedUid = uid
        subscribedViewerUid = viewerUid ?? uid

        activitiesListeners = ActivityService.shared.subscribeProfileActivities(uid: uid, isOwnProfile: isOwnProfile, viewerUid: subscribedViewerUid) { [weak self] activities in
            guard let self else { return }
            self.activities = activities
            self.isLoadingActivities = false
            if let cont = self.refreshContinuation {
                self.refreshContinuation = nil
                cont.resume()
            }
            self.loadTask?.cancel()
            let task = Task { [weak self] in
                guard let self else { return }
                let sources = await ActivityService.shared.loadSourceActivities(for: activities, existing: self.sourceActivities)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.sourceActivities.merge(sources) { _, new in new }
                }
                var allActivities = activities
                allActivities += sources.values
                let map = await ActivityService.shared.getUsersForActivities(allActivities)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.userMap.merge(map) { _, new in new }
                }
            }
            self.loadTask = task
        }
    }

    func refresh(uid: String) async {
        await withCheckedContinuation { continuation in
            self.refreshContinuation = continuation
            subscribe(uid: subscribedUid, isOwnProfile: subscribedIsOwnProfile, viewerUid: subscribedViewerUid)
        }
    }

    func unsubscribe() {
        activitiesListeners.forEach { $0.remove() }
        activitiesListeners.removeAll()
        friendsListener?.remove()
        friendsListener = nil
        loadTask?.cancel()
        loadTask = nil
    }

    var wakeUpSentCount: Int {
        activities.filter { $0.type == .sent }.count
    }

    var wokeUpCount: Int {
        activities.filter { $0.type == .achieved || $0.type == .received_wakeup }.count
    }
}

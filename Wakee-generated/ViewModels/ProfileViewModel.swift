import Foundation
import FirebaseFirestore

@Observable
final class ProfileViewModel {
    var activities: [Activity] = []
    var isLoadingActivities = true
    var friendCount = 0

    private var activitiesListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?

    func subscribe(uid: String) {
        activitiesListener?.remove()
        friendsListener?.remove()

        activitiesListener = ActivityService.shared.subscribeMyActivities(uid: uid) { [weak self] activities in
            self?.activities = activities
            self?.isLoadingActivities = false
        }
        friendsListener = FriendService.shared.subscribeFriends(uid: uid) { [weak self] friends in
            self?.friendCount = friends.count
        }
    }

    func unsubscribe() {
        activitiesListener?.remove()
        friendsListener?.remove()
    }

    var sentCount: Int {
        activities.filter { $0.type == .sent }.count
    }

    var achievedCount: Int {
        activities.filter { $0.type == .achieved }.count
    }
}

import Foundation
import FirebaseFirestore

@Observable
final class HomeViewModel {
    var activities: [Activity] = []
    var userMap: [String: ActivityService.UserInfo] = [:]
    var isLoading = true

    private var feedListener: ListenerRegistration?

    func subscribe(uid: String) {
        feedListener?.remove()
        feedListener = ActivityService.shared.subscribeFeed(uid: uid) { [weak self] activities in
            guard let self else { return }
            self.activities = activities
            self.isLoading = false
            Task {
                let map = await ActivityService.shared.getUsersForActivities(activities)
                await MainActor.run { self.userMap = map }
            }
        }
    }

    func unsubscribe() {
        feedListener?.remove()
        feedListener = nil
    }

    func activityLabel(_ activity: Activity) -> String {
        switch activity.type {
        case .achieved: return "が起きた!"
        case .rejected: return "が二度寝した..."
        case .snoozed: return "がスヌーズした"
        case .sent: return "がアラームを送った"
        case .received_wakeup: return "がアラームを受け取った"
        case .repost: return "がリポストした"
        }
    }

    func activityIcon(_ activity: Activity) -> String {
        switch activity.type {
        case .achieved: return "sun.max.fill"
        case .rejected: return "moon.zzz.fill"
        case .snoozed: return "clock.fill"
        case .sent: return "alarm.fill"
        case .received_wakeup: return "bell.fill"
        case .repost: return "arrow.2.squarepath"
        }
    }
}

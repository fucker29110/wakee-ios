import Foundation
import FirebaseFirestore

@Observable
final class HomeViewModel {
    var activities: [Activity] = []
    var userMap: [String: ActivityService.UserInfo] = [:]
    var sourceActivities: [String: Activity] = [:]
    var isLoading = true

    private var feedListener: ListenerRegistration?
    private var loadTask: Task<Void, Never>?
    private var refreshContinuation: CheckedContinuation<Void, Never>?

    deinit {
        unsubscribe()
    }

    func subscribe(uid: String) {
        feedListener?.remove()
        loadTask?.cancel()
        feedListener = ActivityService.shared.subscribeFeed(uid: uid) { [weak self] activities in
            guard let self else { return }
            self.activities = activities
            self.isLoading = false
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
            subscribe(uid: uid)
        }
    }

    func unsubscribe() {
        feedListener?.remove()
        feedListener = nil
        loadTask?.cancel()
        loadTask = nil
    }
}

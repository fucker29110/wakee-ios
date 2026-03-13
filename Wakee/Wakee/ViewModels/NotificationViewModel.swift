import Foundation
import FirebaseFirestore

@Observable
final class NotificationViewModel {
    var notifications: [AppNotification] = []
    var unreadCount = 0
    var isLoading = true

    private var notifListener: ListenerRegistration?
    private var unreadListener: ListenerRegistration?
    private var refreshContinuation: CheckedContinuation<Void, Never>?

    deinit {
        unsubscribe()
    }

    func subscribe(uid: String) {
        notifListener?.remove()
        unreadListener?.remove()

        notifListener = NotificationHistoryService.shared.subscribe(uid: uid) { [weak self] notifs in
            self?.notifications = notifs
            self?.isLoading = false
            if let cont = self?.refreshContinuation {
                self?.refreshContinuation = nil
                cont.resume()
            }
        }
        unreadListener = NotificationHistoryService.shared.subscribeUnreadCount(uid: uid) { [weak self] count in
            self?.unreadCount = count
        }
    }

    func refresh(uid: String) async {
        await withCheckedContinuation { continuation in
            self.refreshContinuation = continuation
            subscribe(uid: uid)
        }
    }

    func unsubscribe() {
        notifListener?.remove()
        notifListener = nil
        unreadListener?.remove()
        unreadListener = nil
    }

    func markAllAsRead(uid: String) {
        Task {
            try? await NotificationHistoryService.shared.markAllAsRead(uid: uid)
        }
    }
}

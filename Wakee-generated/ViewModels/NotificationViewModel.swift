import Foundation
import FirebaseFirestore

@Observable
final class NotificationViewModel {
    var notifications: [AppNotification] = []
    var unreadCount = 0
    var isLoading = true

    private var notifListener: ListenerRegistration?
    private var unreadListener: ListenerRegistration?

    func subscribe(uid: String) {
        notifListener?.remove()
        unreadListener?.remove()

        notifListener = NotificationHistoryService.shared.subscribe(uid: uid) { [weak self] notifs in
            self?.notifications = notifs
            self?.isLoading = false
        }
        unreadListener = NotificationHistoryService.shared.subscribeUnreadCount(uid: uid) { [weak self] count in
            self?.unreadCount = count
        }
    }

    func unsubscribe() {
        notifListener?.remove()
        unreadListener?.remove()
    }

    func markAllAsRead(uid: String) {
        Task {
            try? await NotificationHistoryService.shared.markAllAsRead(uid: uid)
        }
    }
}

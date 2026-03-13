import Foundation
import FirebaseFirestore

@Observable
final class FriendsViewModel {
    var friends: [AppUser] = []
    var requests: [FollowRequest] = []
    var searchResults: [AppUser] = []
    var searchQuery = ""
    var isSearching = false
    var isLoading = true
    var sentRequests: Set<String> = []

    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?

    func subscribe(uid: String) {
        friendsListener?.remove()
        requestsListener?.remove()

        friendsListener = FriendService.shared.subscribeFriends(uid: uid) { [weak self] friends in
            self?.friends = friends
            self?.isLoading = false
        }
        requestsListener = FriendService.shared.subscribeRequests(uid: uid) { [weak self] requests in
            self?.requests = requests
        }
    }

    func unsubscribe() {
        friendsListener?.remove()
        requestsListener?.remove()
    }

    @MainActor
    func search(myUid: String) async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        do {
            searchResults = try await FriendService.shared.searchByUsername(username: searchQuery, myUid: myUid)
        } catch {
            print("Search error: \(error)")
        }
        isSearching = false
    }

    @MainActor
    func sendRequest(fromUid: String, toUid: String, fromName: String) async {
        do {
            _ = try await FriendService.shared.sendFollowRequest(fromUid: fromUid, toUid: toUid, fromName: fromName)
            sentRequests.insert(toUid)
        } catch {
            print("Send request error: \(error)")
        }
    }

    @MainActor
    func acceptRequest(requestId: String, fromUid: String, toUid: String) async {
        do {
            try await FriendService.shared.acceptRequest(requestId: requestId, fromUid: fromUid, toUid: toUid)
        } catch {
            print("Accept request error: \(error)")
        }
    }

    @MainActor
    func rejectRequest(requestId: String) async {
        do {
            try await FriendService.shared.rejectRequest(requestId: requestId)
        } catch {
            print("Reject request error: \(error)")
        }
    }
}

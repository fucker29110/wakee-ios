import Foundation
import FirebaseFirestore

struct SuggestedFriend: Identifiable {
    var id: String { user.uid }
    let user: AppUser
    let mutualCount: Int
}

@Observable
final class FriendsViewModel {
    var friends: [AppUser] = []
    var requests: [FollowRequest] = []
    var suggestions: [SuggestedFriend] = []
    var searchResults: [AppUser] = []
    var searchQuery = "" {
        didSet { scheduleSearch() }
    }
    var isSearching = false
    var isLoading = true
    var isLoadingSuggestions = false
    var sentRequests: Set<String> = []

    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var searchTask: Task<Void, Never>?
    var searchUid: String?

    deinit {
        unsubscribe()
        searchTask?.cancel()
    }

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
        friendsListener = nil
        requestsListener?.remove()
        requestsListener = nil
    }

    @MainActor
    func fetchSuggestions(uid: String) async {
        isLoadingSuggestions = true
        do {
            let results = try await FriendService.shared.fetchSuggestions(uid: uid)
            suggestions = results.map { SuggestedFriend(user: $0.user, mutualCount: $0.mutualCount) }
        } catch {
            print("Fetch suggestions error: \(error)")
        }
        isLoadingSuggestions = false
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self, let uid = self.searchUid else { return }
            self.isSearching = true
            do {
                self.searchResults = try await FriendService.shared.searchByUsername(username: query, myUid: uid)
            } catch {
                if !Task.isCancelled { print("Search error: \(error)") }
            }
            if !Task.isCancelled { self.isSearching = false }
        }
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
    func sendRequest(fromUid: String, toUid: String, fromName: String, fromUsername: String) async {
        do {
            _ = try await FriendService.shared.sendFollowRequest(fromUid: fromUid, toUid: toUid, fromName: fromName, fromUsername: fromUsername)
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

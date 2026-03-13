import Foundation
import FirebaseFirestore

@Observable
final class StoryViewModel {
    var stories: [Story] = []
    var myStory: Story?
    var isPosting = false

    private var storyListeners: [ListenerRegistration] = []

    deinit {
        unsubscribe()
    }

    func subscribe(uid: String, friendUids: [String]) {
        unsubscribe()
        Task {
            myStory = try? await StoryService.shared.getMyActiveStory(uid: uid)
        }
        let allUids = friendUids + [uid]
        storyListeners = StoryService.shared.subscribeActiveStories(friendUids: allUids) { [weak self] stories in
            guard let self else { return }
            self.myStory = stories.first { $0.authorUid == uid }
            self.stories = stories.filter { $0.authorUid != uid }
        }
    }

    func unsubscribe() {
        storyListeners.forEach { $0.remove() }
        storyListeners.removeAll()
    }

    @MainActor
    func postStory(uid: String, text: String) async {
        isPosting = true
        do {
            try await StoryService.shared.postStory(uid: uid, text: text)
            myStory = try await StoryService.shared.getMyActiveStory(uid: uid)
        } catch {
            print("Story post error: \(error)")
        }
        isPosting = false
    }

    func markAsRead(storyId: String, uid: String) {
        Task {
            try? await StoryService.shared.markAsRead(storyId: storyId, uid: uid)
        }
    }

    @MainActor
    func deleteStory(storyId: String) async {
        do {
            try await StoryService.shared.deleteStory(storyId: storyId)
            myStory = nil
        } catch {
            print("Story delete error: \(error)")
        }
    }

    @MainActor
    func editStory(storyId: String, text: String) async {
        do {
            try await StoryService.shared.editStory(storyId: storyId, text: text)
            myStory?.text = text
        } catch {
            print("Story edit error: \(error)")
        }
    }
}

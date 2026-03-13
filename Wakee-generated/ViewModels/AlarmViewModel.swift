import Foundation
import FirebaseFirestore

@Observable
final class AlarmViewModel {
    var selectedFriends: Set<String> = []
    var time = "07:00"
    var message = ""
    var isSending = false
    var recordingData: Data?
    var showRecordingModal = false

    private let defaultSnoozeMin = 10
    private let maxMessageLength = 200

    var canSend: Bool {
        !selectedFriends.isEmpty && !isSending
    }

    func toggleFriend(_ uid: String) {
        if selectedFriends.contains(uid) {
            selectedFriends.remove(uid)
        } else {
            selectedFriends.insert(uid)
        }
    }

    @MainActor
    func sendAlarm(user: AppUser, friends: [AppUser]) async -> Bool {
        guard canSend else { return false }
        isSending = true
        defer { isSending = false }

        do {
            var audioURL: String?
            if let data = recordingData {
                audioURL = try await StorageService.shared.uploadAlarmAudio(
                    senderUid: user.uid,
                    audioData: data
                )
            }

            let targets = Array(selectedFriends)
            for receiverUid in targets {
                _ = try await AlarmService.shared.sendAlarm(
                    senderUid: user.uid,
                    senderName: user.displayName,
                    receiverUid: receiverUid,
                    time: time,
                    label: "\(user.displayName)からのアラーム",
                    message: message,
                    snoozeMin: defaultSnoozeMin,
                    audioURL: audioURL
                )
            }

            let friendUids = try await FriendService.shared.getFriendUids(uid: user.uid)
            let visibleTo = Array(Set([user.uid] + friendUids))

            for receiverUid in targets {
                try await ActivityService.shared.record(
                    type: .sent,
                    actorUid: user.uid,
                    targetUid: receiverUid,
                    time: time,
                    message: message.isEmpty ? nil : message,
                    visibleTo: visibleTo
                )
            }

            selectedFriends.removeAll()
            message = ""
            recordingData = nil
            return true
        } catch {
            print("Send alarm error: \(error)")
            return false
        }
    }
}

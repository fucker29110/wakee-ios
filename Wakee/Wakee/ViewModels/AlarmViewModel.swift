import Foundation
import FirebaseFirestore

@Observable
final class AlarmViewModel {
    var selectedFriends: Set<String> = []
    var time = "07:00"
    var message = ""
    var isPrivate = false
    var isSending = false

    private let defaultSnoozeMin = 10
    let maxMessageLength = 200

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
    func sendAlarm(user: AppUser, friends: [AppUser], recordingService: AudioRecordingService? = nil) async -> Bool {
        guard canSend else { return false }
        isSending = true
        defer { isSending = false }

        do {
            let targets = Array(selectedFriends)

            // 録音がある場合はアップロード
            var audioURL: String? = nil
            if let recordingService, recordingService.recordedFileURL != nil {
                let uploadEventId = UUID().uuidString
                audioURL = try await recordingService.uploadRecording(eventId: uploadEventId)
            }

            var eventIds: [String: String] = [:]  // receiverUid → eventId
            for receiverUid in targets {
                let eventId = try await AlarmService.shared.sendAlarm(
                    senderUid: user.uid,
                    senderName: user.displayName,
                    receiverUid: receiverUid,
                    time: time,
                    label: "\(user.displayName)からのアラーム",
                    message: message,
                    snoozeMin: defaultSnoozeMin,
                    audioURL: audioURL,
                    isPrivate: isPrivate
                )
                eventIds[receiverUid] = eventId
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
                    visibleTo: visibleTo,
                    isPrivate: isPrivate
                )
            }

            // Live Activity 開始（送信側で受信者の状態をトラッキング）
            let receivers = targets.compactMap { uid -> (uid: String, username: String)? in
                guard let friend = friends.first(where: { $0.uid == uid }) else { return nil }
                return (uid: friend.uid, username: friend.username)
            }
            LiveActivityService.shared.startActivity(
                alarmTime: time,
                senderUsername: user.username,
                receivers: receivers,
                eventIds: eventIds
            )

            selectedFriends.removeAll()
            message = ""
            isPrivate = false
            return true
        } catch {
            print("Send alarm error: \(error)")
            return false
        }
    }
}

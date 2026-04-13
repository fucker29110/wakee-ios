import Foundation
import FirebaseFirestore

struct UserSettings: Codable {
    var searchable: Bool
    var blocked: [String]

    init(searchable: Bool = true, blocked: [String] = []) {
        self.searchable = searchable
        self.blocked = blocked
    }
}

struct NotificationSettings: Codable {
    var alarmReceived: Bool
    var messages: Bool
    var likes: Bool
    var reposts: Bool
    var friendRequests: Bool
    var reactions: Bool
    var liveActivity: Bool

    init(
        alarmReceived: Bool = true,
        messages: Bool = true,
        likes: Bool = true,
        reposts: Bool = true,
        friendRequests: Bool = true,
        reactions: Bool = true,
        liveActivity: Bool = true
    ) {
        self.alarmReceived = alarmReceived
        self.messages = messages
        self.likes = likes
        self.reposts = reposts
        self.friendRequests = friendRequests
        self.reactions = reactions
        self.liveActivity = liveActivity
    }
}

struct AppUser: Identifiable, Codable, Hashable {
    static func == (lhs: AppUser, rhs: AppUser) -> Bool { lhs.uid == rhs.uid }
    func hash(into hasher: inout Hasher) { hasher.combine(uid) }
    var id: String { uid }
    var uid: String
    var displayName: String
    var photoURL: String?
    var username: String
    var email: String
    var bio: String
    var location: String
    var settings: UserSettings
    var notificationSettings: NotificationSettings
    var fcmToken: String?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    init(
        uid: String,
        displayName: String,
        photoURL: String? = nil,
        username: String = "",
        email: String = "",
        bio: String = "",
        location: String = "",
        settings: UserSettings = UserSettings(),
        notificationSettings: NotificationSettings = NotificationSettings(),
        fcmToken: String? = nil,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.photoURL = photoURL
        self.username = username
        self.email = email
        self.bio = bio
        self.location = location
        self.settings = settings
        self.notificationSettings = notificationSettings
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case uid, displayName, photoURL, username, email, bio, location, settings, notificationSettings, fcmToken, createdAt, updatedAt
    }
}

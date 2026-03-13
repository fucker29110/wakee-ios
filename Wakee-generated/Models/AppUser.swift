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

struct AppUser: Identifiable, Codable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var photoURL: String?
    var username: String
    var bio: String
    var location: String
    var streak: Int
    var settings: UserSettings
    var fcmToken: String?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    init(
        uid: String,
        displayName: String,
        photoURL: String? = nil,
        username: String = "",
        bio: String = "",
        location: String = "",
        streak: Int = 0,
        settings: UserSettings = UserSettings(),
        fcmToken: String? = nil,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.photoURL = photoURL
        self.username = username
        self.bio = bio
        self.location = location
        self.streak = streak
        self.settings = settings
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case uid, displayName, photoURL, username, bio, location, streak, settings, fcmToken, createdAt, updatedAt
    }
}

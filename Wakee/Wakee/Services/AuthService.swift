import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

final class AuthService {
    static let shared = AuthService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Username generation
    private func generateUsername(displayName: String, uid: String) -> String {
        let base = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }
        let prefix = base.isEmpty ? "user" : base
        let suffix = String(uid.prefix(4))
        return "\(prefix)_\(suffix)"
    }

    // MARK: - Create or get user document
    /// Returns (user, isNewUser)
    func createOrGetUserDocument(firebaseUser: FirebaseAuth.User) async throws -> (AppUser, Bool) {
        let userRef = db.collection("users").document(firebaseUser.uid)
        let snap = try await userRef.getDocument()

        if snap.exists, let data = snap.data() {
            // 既存ユーザーの email バックフィル
            if data["email"] == nil || (data["email"] as? String)?.isEmpty == true,
               let fbEmail = firebaseUser.email, !fbEmail.isEmpty {
                try await userRef.updateData(["email": fbEmail])
            }
            let user = decodeUser(uid: firebaseUser.uid, data: data)
            // onboardingCompleted フラグが false なら新規扱い
            let onboarded = data["onboardingCompleted"] as? Bool ?? true
            return (user, !onboarded)
        }

        let username = generateUsername(
            displayName: firebaseUser.displayName ?? "user",
            uid: firebaseUser.uid
        )
        let newData: [String: Any] = [
            "displayName": firebaseUser.displayName ?? LanguageManager.shared.l("common.user"),
            "photoURL": firebaseUser.photoURL?.absoluteString as Any,
            "username": username,
            "email": firebaseUser.email ?? "",
            "bio": "",
            "location": "",
            "settings": ["searchable": true, "blocked": [String]()],
            "notificationSettings": [
                "alarmReceived": true,
                "messages": true,
                "likes": true,
                "reposts": true,
                "friendRequests": true,
                "reactions": true,
                "liveActivity": true,
            ],
            "onboardingCompleted": false,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await userRef.setData(newData)
        let user = AppUser(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? LanguageManager.shared.l("common.user"),
            photoURL: firebaseUser.photoURL?.absoluteString,
            username: username,
            email: firebaseUser.email ?? ""
        )
        return (user, true)
    }

    func completeOnboarding(uid: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "onboardingCompleted": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func decodeUser(uid: String, data: [String: Any]) -> AppUser {
        let settingsData = data["settings"] as? [String: Any] ?? [:]
        let settings = UserSettings(
            searchable: settingsData["searchable"] as? Bool ?? true,
            blocked: settingsData["blocked"] as? [String] ?? []
        )
        let notifData = data["notificationSettings"] as? [String: Any] ?? [:]
        let notificationSettings = NotificationSettings(
            alarmReceived: notifData["alarmReceived"] as? Bool ?? true,
            messages: notifData["messages"] as? Bool ?? true,
            likes: notifData["likes"] as? Bool ?? true,
            reposts: notifData["reposts"] as? Bool ?? true,
            friendRequests: notifData["friendRequests"] as? Bool ?? true,
            reactions: notifData["reactions"] as? Bool ?? true,
            liveActivity: notifData["liveActivity"] as? Bool ?? true
        )
        return AppUser(
            uid: uid,
            displayName: data["displayName"] as? String ?? LanguageManager.shared.l("common.user"),
            photoURL: data["photoURL"] as? String,
            username: data["username"] as? String ?? "",
            email: data["email"] as? String ?? "",
            bio: data["bio"] as? String ?? "",
            location: data["location"] as? String ?? "",
            settings: settings,
            notificationSettings: notificationSettings,
            fcmToken: data["fcmToken"] as? String,
            createdAt: data["createdAt"] as? Timestamp,
            updatedAt: data["updatedAt"] as? Timestamp
        )
    }

    // MARK: - Profile
    func isUsernameAvailable(username: String, myUid: String) async throws -> Bool {
        let snap = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        if snap.documents.isEmpty { return true }
        return snap.documents.first?.documentID == myUid
    }

    func updateUserProfile(uid: String, params: [String: Any]) async throws {
        var updates = params
        updates["updatedAt"] = FieldValue.serverTimestamp()
        try await db.collection("users").document(uid).updateData(updates)
    }

    func saveFcmToken(uid: String, token: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async throws -> (AppUser, Bool) {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = await windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return try await createOrGetUserDocument(firebaseUser: authResult.user)
    }

    // MARK: - Apple Sign-In
    func signInWithApple(authorization: ASAuthorization, nonce: String) async throws -> (AppUser, Bool) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: credential)

        if authResult.user.displayName == nil || authResult.user.displayName?.isEmpty == true {
            let name = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")
            if !name.isEmpty {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }
        }
        return try await createOrGetUserDocument(firebaseUser: authResult.user)
    }

    // MARK: - Email/Password
    func signInWithEmail(email: String, password: String) async throws -> (AppUser, Bool) {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await createOrGetUserDocument(firebaseUser: result.user)
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws -> (AppUser, Bool) {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        return try await createOrGetUserDocument(firebaseUser: result.user)
    }

    // MARK: - Phone
    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        return try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
    }

    func signInWithPhoneCode(verificationId: String, code: String) async throws -> (AppUser, Bool) {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        return try await createOrGetUserDocument(firebaseUser: result.user)
    }

    // MARK: - Password Reset
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Email Verification
    func sendEmailVerification() async throws {
        try await Auth.auth().currentUser?.sendEmailVerification()
    }

    var isEmailVerified: Bool {
        Auth.auth().currentUser?.isEmailVerified ?? false
    }

    func reloadCurrentUser() async throws {
        try await Auth.auth().currentUser?.reload()
    }

    // MARK: - Reauthentication & Account Changes
    func reauthenticateWithPassword(_ password: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else { throw AuthError.missingToken }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }

    func changeEmail(to newEmail: String) async throws {
        try await Auth.auth().currentUser?.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }

    func changePassword(to newPassword: String) async throws {
        try await Auth.auth().currentUser?.updatePassword(to: newPassword)
    }

    var hasPasswordProvider: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    // MARK: - Username Resolution
    func resolveUsernameToEmail(_ username: String) async throws -> String {
        let snap = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased().trimmingCharacters(in: .whitespaces))
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first,
              let email = doc.data()["email"] as? String, !email.isEmpty else {
            throw AuthError.usernameNotFound
        }
        return email
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Apple Sign-In Helpers
    static func randomNonceString(length: Int = 32) -> String {
        guard length > 0 else { return "" }
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            // フォールバック: UUID ベースのランダム文字列
            return (0..<length).map { _ in
                let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
                return String(charset.randomElement() ?? "0")
            }.joined()
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case noRootViewController
    case missingToken
    case usernameNotFound

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return LanguageManager.shared.l("service.root_vc_not_found")
        case .missingToken: return LanguageManager.shared.l("service.auth_token_failed")
        case .usernameNotFound: return LanguageManager.shared.l("auth.username_not_found")
        }
    }
}

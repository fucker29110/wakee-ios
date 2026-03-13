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
    func createOrGetUserDocument(firebaseUser: FirebaseAuth.User) async throws -> AppUser {
        let userRef = db.collection("users").document(firebaseUser.uid)
        let snap = try await userRef.getDocument()

        if snap.exists, let data = snap.data() {
            return decodeUser(uid: firebaseUser.uid, data: data)
        }

        let username = generateUsername(
            displayName: firebaseUser.displayName ?? "user",
            uid: firebaseUser.uid
        )
        let newData: [String: Any] = [
            "displayName": firebaseUser.displayName ?? "ユーザー",
            "photoURL": firebaseUser.photoURL?.absoluteString as Any,
            "username": username,
            "bio": "",
            "location": "",
            "streak": 0,
            "settings": ["searchable": true, "blocked": [String]()],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await userRef.setData(newData)
        return AppUser(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? "ユーザー",
            photoURL: firebaseUser.photoURL?.absoluteString,
            username: username
        )
    }

    private func decodeUser(uid: String, data: [String: Any]) -> AppUser {
        let settingsData = data["settings"] as? [String: Any] ?? [:]
        let settings = UserSettings(
            searchable: settingsData["searchable"] as? Bool ?? true,
            blocked: settingsData["blocked"] as? [String] ?? []
        )
        return AppUser(
            uid: uid,
            displayName: data["displayName"] as? String ?? "ユーザー",
            photoURL: data["photoURL"] as? String,
            username: data["username"] as? String ?? "",
            bio: data["bio"] as? String ?? "",
            location: data["location"] as? String ?? "",
            streak: data["streak"] as? Int ?? 0,
            settings: settings,
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
        return snap.documents[0].documentID == myUid
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
    func signInWithGoogle() async throws -> AppUser {
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
    func signInWithApple(authorization: ASAuthorization, nonce: String) async throws -> AppUser {
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
    func signInWithEmail(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await createOrGetUserDocument(firebaseUser: result.user)
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws -> AppUser {
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

    func signInWithPhoneCode(verificationId: String, code: String) async throws -> AppUser {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        return try await createOrGetUserDocument(firebaseUser: result.user)
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Apple Sign-In Helpers
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess { fatalError("Unable to generate nonce.") }
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

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "ルートビューコントローラーが見つかりません"
        case .missingToken: return "認証トークンの取得に失敗しました"
        }
    }
}

import Foundation
import FirebaseAuth
import AuthenticationServices

@Observable
final class AuthViewModel {
    var user: AppUser?
    var isLoading = true
    var needsOnboarding = false
    var needsEmailVerification = false
    var errorMessage: String?
    var showEmailForm = false
    var emailMode: EmailMode = .login
    var email = ""
    var password = ""
    var displayName = ""
    var loginIdentifier = ""

    private var authListener: AuthStateDidChangeListenerHandle?

    enum EmailMode {
        case login, signup
    }

    init() {
        listenToAuthState()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func listenToAuthState() {
        isLoading = true
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self else { return }
                if let firebaseUser {
                    do {
                        let (user, isNew) = try await AuthService.shared.createOrGetUserDocument(firebaseUser: firebaseUser)
                        self.user = user
                        self.needsOnboarding = isNew
                    } catch {
                        print("Auth state error: \(error)")
                        self.user = nil
                    }
                } else {
                    self.user = nil
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Google
    @MainActor
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            let (user, isNew) = try await AuthService.shared.signInWithGoogle()
            self.user = user
            self.needsOnboarding = isNew
        } catch {
            errorMessage = mapFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Apple
    @MainActor
    func handleAppleSignIn(result: Result<ASAuthorization, Error>, nonce: String) async {
        isLoading = true
        errorMessage = nil
        switch result {
        case .success(let authorization):
            do {
                let (user, isNew) = try await AuthService.shared.signInWithApple(authorization: authorization, nonce: nonce)
                self.user = user
                self.needsOnboarding = isNew
            } catch {
                errorMessage = mapFirebaseError(error)
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = LanguageManager.shared.l("auth.apple_signin_failed")
            }
        }
        isLoading = false
    }

    // MARK: - Email
    @MainActor
    func signInWithEmail() async {
        if emailMode == .login {
            guard !loginIdentifier.isEmpty, !password.isEmpty else {
                errorMessage = LanguageManager.shared.l("auth.enter_email_password")
                return
            }
        } else {
            guard !email.isEmpty, !password.isEmpty else {
                errorMessage = LanguageManager.shared.l("auth.enter_email_password")
                return
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            if emailMode == .signup {
                guard password.count >= 6 else {
                    errorMessage = LanguageManager.shared.l("auth.password_min_length")
                    isLoading = false
                    return
                }
                let name = displayName.isEmpty ? LanguageManager.shared.l("auth.default_name") : displayName
                let (user, isNew) = try await AuthService.shared.signUpWithEmail(email: email, password: password, displayName: name)
                self.user = user
                self.needsOnboarding = isNew
                // メール認証送信
                try await AuthService.shared.sendEmailVerification()
                self.needsEmailVerification = true
            } else {
                // ユーザー名 or メールアドレスでログイン
                var resolvedEmail = loginIdentifier
                if !loginIdentifier.contains("@") {
                    resolvedEmail = try await AuthService.shared.resolveUsernameToEmail(loginIdentifier)
                }
                let (user, isNew) = try await AuthService.shared.signInWithEmail(email: resolvedEmail, password: password)
                self.user = user
                self.needsOnboarding = isNew
            }
        } catch {
            errorMessage = mapFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Email Verification
    @MainActor
    func checkEmailVerification() async {
        do {
            try await AuthService.shared.reloadCurrentUser()
            if AuthService.shared.isEmailVerified {
                needsEmailVerification = false
            } else {
                errorMessage = LanguageManager.shared.l("verify.check_inbox")
            }
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    @MainActor
    func resendVerification() async {
        do {
            try await AuthService.shared.sendEmailVerification()
            errorMessage = LanguageManager.shared.l("verify.resent")
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Sign Out
    @MainActor
    func signOut() {
        do {
            try AuthService.shared.signOut()
            user = nil
            needsOnboarding = false
            needsEmailVerification = false
            errorMessage = nil
            email = ""
            password = ""
            displayName = ""
            loginIdentifier = ""
        } catch {
            errorMessage = LanguageManager.shared.l("auth.logout_failed")
        }
    }

    // MARK: - Profile Update
    @MainActor
    func updateProfile(params: [String: Any]) async {
        guard let uid = user?.uid else { return }
        do {
            try await AuthService.shared.updateUserProfile(uid: uid, params: params)
            if let name = params["displayName"] as? String { user?.displayName = name }
            if let username = params["username"] as? String { user?.username = username }
            if let bio = params["bio"] as? String { user?.bio = bio }
            if let location = params["location"] as? String { user?.location = location }
            if let photoURL = params["photoURL"] as? String { user?.photoURL = photoURL }
        } catch {
            errorMessage = LanguageManager.shared.l("auth.profile_update_failed")
        }
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return LanguageManager.shared.l("auth.wrong_password")
        case AuthErrorCode.invalidEmail.rawValue:
            return LanguageManager.shared.l("auth.invalid_email")
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return LanguageManager.shared.l("auth.email_in_use")
        case AuthErrorCode.userNotFound.rawValue:
            return LanguageManager.shared.l("auth.account_not_found")
        case AuthErrorCode.networkError.rawValue:
            return LanguageManager.shared.l("auth.network_error")
        case AuthErrorCode.tooManyRequests.rawValue:
            return LanguageManager.shared.l("auth.too_many_requests")
        default:
            return error.localizedDescription
        }
    }
}

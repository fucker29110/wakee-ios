import Foundation
import FirebaseAuth
import AuthenticationServices

@Observable
final class AuthViewModel {
    var user: AppUser?
    var isLoading = true
    var needsOnboarding = false
    var errorMessage: String?
    var showEmailForm = false
    var emailMode: EmailMode = .login
    var email = ""
    var password = ""
    var displayName = ""

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
                errorMessage = "Apple サインインに失敗しました"
            }
        }
        isLoading = false
    }

    // MARK: - Email
    @MainActor
    func signInWithEmail() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            if emailMode == .signup {
                guard password.count >= 6 else {
                    errorMessage = "パスワードは6文字以上必要です"
                    isLoading = false
                    return
                }
                let name = displayName.isEmpty ? "ユーザー" : displayName
                let (user, isNew) = try await AuthService.shared.signUpWithEmail(email: email, password: password, displayName: name)
                self.user = user
                self.needsOnboarding = isNew
            } else {
                let (user, isNew) = try await AuthService.shared.signInWithEmail(email: email, password: password)
                self.user = user
                self.needsOnboarding = isNew
            }
        } catch {
            errorMessage = mapFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Sign Out
    @MainActor
    func signOut() {
        do {
            try AuthService.shared.signOut()
            user = nil
            needsOnboarding = false
            errorMessage = nil
            email = ""
            password = ""
            displayName = ""
        } catch {
            errorMessage = "ログアウトに失敗しました"
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
            errorMessage = "プロフィールの更新に失敗しました"
        }
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "パスワードが正しくありません"
        case AuthErrorCode.invalidEmail.rawValue:
            return "メールアドレスの形式が正しくありません"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "このメールアドレスは既に使用されています"
        case AuthErrorCode.userNotFound.rawValue:
            return "アカウントが見つかりません"
        case AuthErrorCode.networkError.rawValue:
            return "ネットワークエラーが発生しました"
        case AuthErrorCode.tooManyRequests.rawValue:
            return "リクエストが多すぎます。しばらくお待ちください"
        default:
            return error.localizedDescription
        }
    }
}

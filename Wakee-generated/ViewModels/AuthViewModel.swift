import Foundation
import FirebaseAuth
import AuthenticationServices

@Observable
final class AuthViewModel {
    var user: AppUser?
    var isLoading = true
    var errorMessage: String?
    var showEmailForm = false
    var emailMode: EmailMode = .login
    var email = ""
    var password = ""
    var displayName = ""
    var showPhoneModal = false
    var phoneNumber = ""
    var verificationId: String?
    var smsCode = ""

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
                        self.user = try await AuthService.shared.createOrGetUserDocument(firebaseUser: firebaseUser)
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
            user = try await AuthService.shared.signInWithGoogle()
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
                user = try await AuthService.shared.signInWithApple(authorization: authorization, nonce: nonce)
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
                guard !displayName.isEmpty else {
                    errorMessage = "表示名を入力してください"
                    isLoading = false
                    return
                }
                guard password.count >= 6 else {
                    errorMessage = "パスワードは6文字以上必要です"
                    isLoading = false
                    return
                }
                user = try await AuthService.shared.signUpWithEmail(email: email, password: password, displayName: displayName)
            } else {
                user = try await AuthService.shared.signInWithEmail(email: email, password: password)
            }
        } catch {
            errorMessage = mapFirebaseError(error)
        }
        isLoading = false
    }

    // MARK: - Phone
    @MainActor
    func sendPhoneVerification() async {
        guard !phoneNumber.isEmpty else {
            errorMessage = "電話番号を入力してください"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let formatted = phoneNumber.hasPrefix("+") ? phoneNumber : "+81\(phoneNumber)"
            verificationId = try await AuthService.shared.verifyPhoneNumber(formatted)
        } catch {
            errorMessage = mapFirebaseError(error)
        }
        isLoading = false
    }

    @MainActor
    func verifyPhoneCode() async {
        guard let verificationId, !smsCode.isEmpty else {
            errorMessage = "認証コードを入力してください"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            user = try await AuthService.shared.signInWithPhoneCode(verificationId: verificationId, code: smsCode)
            showPhoneModal = false
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

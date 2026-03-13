import SwiftUI
import AuthenticationServices

// MARK: - Auth Flow Step
private enum AuthStep {
    case welcome
    case register
    case login
}

struct LoginScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var currentNonce: String?
    @State private var step: AuthStep = .welcome

    var body: some View {
        @Bindable var vm = authVM

        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            switch step {
            case .welcome:
                welcomeView
            case .register:
                methodSelectionView(isRegister: true)
            case .login:
                methodSelectionView(isRegister: false)
            }
        }
    }

    // MARK: - 画面1: Welcome

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()

            logoSection

            Spacer()

            VStack(spacing: AppTheme.Spacing.md) {
                registerButton
                loginLink
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer().frame(height: 40)

            termsText
                .padding(.bottom, AppTheme.Spacing.lg)
        }
    }

    private var logoSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text("Wakee")
                .font(.system(size: AppTheme.FontSize.xxl, weight: .heavy))
                .foregroundStyle(AppTheme.accentGradient)
            Text("友達を起こそう")
                .font(.system(size: AppTheme.FontSize.md))
                .foregroundColor(AppTheme.Colors.secondary)
        }
    }

    private var registerButton: some View {
        Button {
            withAnimation { step = .register }
        } label: {
            Text("登録する")
                .font(.system(size: AppTheme.FontSize.md, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                        .fill(AppTheme.accentGradient)
                )
        }
    }

    private var loginLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundColor(AppTheme.Colors.secondary)
            Button("ログイン") {
                withAnimation { step = .login }
            }
            .foregroundColor(AppTheme.Colors.accent)
        }
        .font(.system(size: AppTheme.FontSize.sm))
    }

    private var termsText: some View {
        Text("利用規約・プライバシーポリシー")
            .font(.system(size: AppTheme.FontSize.xs))
            .foregroundColor(AppTheme.Colors.secondary)
    }

    // MARK: - 画面2: Method Selection

    private func methodSelectionView(isRegister: Bool) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer().frame(height: 40)

                methodHeader(isRegister: isRegister)

                Spacer().frame(height: 20)

                methodButtons(isRegister: isRegister)

                if authVM.showEmailForm {
                    emailForm
                }

                errorMessage

                Spacer()
            }
        }
    }

    private func methodHeader(isRegister: Bool) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                withAnimation {
                    step = .welcome
                    authVM.showEmailForm = false
                    authVM.errorMessage = nil
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.Colors.primary)
                    Spacer()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            Text(isRegister ? "アカウントを作成" : "ログイン")
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
    }

    private func methodButtons(isRegister: Bool) -> some View {
        let label = isRegister ? "登録" : "ログイン"
        return VStack(spacing: AppTheme.Spacing.md) {
            googleButton(label: label)
            appleButton(label: label)
            emailButton(label: label)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - Auth Buttons

    private func googleButton(label: String) -> some View {
        Button {
            Task { await authVM.signInWithGoogle() }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                GoogleLogoView(size: 20)
                Text("Googleで\(label)")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
            )
        }
    }

    private func appleButton(label: String) -> some View {
        SignInWithAppleButton(label == "登録" ? .signUp : .signIn) { request in
            let nonce = AuthService.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AuthService.sha256(nonce)
        } onCompletion: { result in
            guard let nonce = currentNonce else { return }
            Task { await authVM.handleAppleSignIn(result: result, nonce: nonce) }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .cornerRadius(AppTheme.BorderRadius.md)
    }

    private func emailButton(label: String) -> some View {
        Button {
            withAnimation {
                authVM.emailMode = step == .register ? .signup : .login
                authVM.showEmailForm.toggle()
                authVM.errorMessage = nil
            }
        } label: {
            authButtonLabel(icon: "envelope.fill", text: "メールで\(label)")
        }
    }

    private func authButtonLabel(icon: String, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(text)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Error

    @ViewBuilder
    private var errorMessage: some View {
        if let error = authVM.errorMessage {
            Text(error)
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundColor(AppTheme.Colors.danger)
                .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Email Form

    private var emailForm: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("メールアドレス", text: Binding(
                get: { authVM.email },
                set: { authVM.email = $0 }
            ))
            .textFieldStyle(DarkTextFieldStyle())
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            SecureField("パスワード", text: Binding(
                get: { authVM.password },
                set: { authVM.password = $0 }
            ))
            .textFieldStyle(DarkTextFieldStyle())

            GradientButton(
                title: authVM.emailMode == .signup ? "新規登録" : "ログイン",
                isLoading: authVM.isLoading
            ) {
                Task { await authVM.signInWithEmail() }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

}

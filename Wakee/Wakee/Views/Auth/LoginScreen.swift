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
    @Environment(LanguageManager.self) private var lang
    @State private var currentNonce: String?
    @AppStorage("hasAgreedToEULA") private var hasAgreedToEULA = false
    @State private var agreedToTerms = false
    @State private var step: AuthStep = .welcome
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotMessage: String?
    @State private var forgotIsError = false
    @State private var forgotIsLoading = false

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
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
    }

    // MARK: - 画面1: Welcome

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()

            logoSection

            Spacer()

            VStack(spacing: AppTheme.Spacing.md) {
                termsAgreement
                registerButton
                    .disabled(!agreedToTerms)
                    .opacity(agreedToTerms ? 1.0 : 0.5)
                loginLink
                    .disabled(!agreedToTerms)
                    .opacity(agreedToTerms ? 1.0 : 0.5)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
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
            Text(lang.l("auth.wake_up_friends"))
                .font(.system(size: AppTheme.FontSize.md))
                .foregroundColor(AppTheme.Colors.secondary)
        }
    }

    private var registerButton: some View {
        Button {
            hasAgreedToEULA = true
            withAnimation { step = .register }
        } label: {
            Text(lang.l("auth.sign_up"))
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
            Text(lang.l("auth.already_have_account"))
                .foregroundColor(AppTheme.Colors.secondary)
            Button(lang.l("auth.login")) {
                hasAgreedToEULA = true
                withAnimation { step = .login }
            }
            .foregroundColor(AppTheme.Colors.accent)
        }
        .font(.system(size: AppTheme.FontSize.sm))
    }

    private var termsAgreement: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Button {
                agreedToTerms.toggle()
            } label: {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundColor(agreedToTerms ? AppTheme.Colors.accent : AppTheme.Colors.secondary)
                    .font(.system(size: 22))
            }

            Group {
                if let attributed = try? AttributedString(markdown: lang.l("auth.agree_to_terms_md")) {
                    Text(attributed)
                } else {
                    Text(lang.l("auth.agree_to_terms_md"))
                }
            }
            .font(.system(size: AppTheme.FontSize.sm))
            .foregroundColor(AppTheme.Colors.secondary)
            .tint(AppTheme.Colors.accent)
            .multilineTextAlignment(.leading)
        }
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

            Text(isRegister ? lang.l("auth.create_account") : lang.l("auth.login"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
    }

    private func methodButtons(isRegister: Bool) -> some View {
        let label = isRegister ? lang.l("auth.register") : lang.l("auth.login")
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
                Text(lang.l("auth.google_auth", args: label))
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
        SignInWithAppleButton(label == lang.l("auth.register") ? .signUp : .signIn) { request in
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
            authButtonLabel(icon: "envelope.fill", text: lang.l("auth.email_auth", args: label))
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
            if authVM.emailMode == .login {
                // ログイン: メールアドレスまたはユーザー名
                TextField(lang.l("auth.email_or_username"), text: Binding(
                    get: { authVM.loginIdentifier },
                    set: { authVM.loginIdentifier = $0 }
                ))
                .textFieldStyle(DarkTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } else {
                // サインアップ: メールアドレスのみ
                TextField(lang.l("auth.email_address"), text: Binding(
                    get: { authVM.email },
                    set: { authVM.email = $0 }
                ))
                .textFieldStyle(DarkTextFieldStyle())
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            SecureField(lang.l("auth.password"), text: Binding(
                get: { authVM.password },
                set: { authVM.password = $0 }
            ))
            .textFieldStyle(DarkTextFieldStyle())

            if authVM.emailMode == .login {
                HStack {
                    Spacer()
                    Button(lang.l("auth.forgot_password")) {
                        forgotEmail = authVM.loginIdentifier.contains("@") ? authVM.loginIdentifier : ""
                        forgotMessage = nil
                        showForgotPassword = true
                    }
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.accent)
                }
            }

            GradientButton(
                title: authVM.emailMode == .signup ? lang.l("auth.sign_up_submit") : lang.l("auth.login"),
                isLoading: authVM.isLoading
            ) {
                Task { await authVM.signInWithEmail() }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    Spacer().frame(height: AppTheme.Spacing.md)

                    Text(lang.l("auth.forgot_password_desc"))
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .multilineTextAlignment(.center)

                    TextField(lang.l("auth.email_address"), text: $forgotEmail)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let message = forgotMessage {
                        Text(message)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(forgotIsError ? AppTheme.Colors.danger : AppTheme.Colors.accent)
                    }

                    GradientButton(
                        title: lang.l("auth.send_reset_email"),
                        isLoading: forgotIsLoading,
                        disabled: forgotEmail.isEmpty
                    ) {
                        Task { await sendPasswordReset() }
                    }

                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .navigationTitle(lang.l("auth.forgot_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.close")) { showForgotPassword = false }
                }
            }
        }
    }

    private func sendPasswordReset() async {
        forgotIsLoading = true
        forgotMessage = nil
        do {
            try await AuthService.shared.sendPasswordReset(email: forgotEmail)
            forgotIsError = false
            forgotMessage = lang.l("auth.reset_email_sent")
        } catch {
            forgotIsError = true
            forgotMessage = error.localizedDescription
        }
        forgotIsLoading = false
    }
}

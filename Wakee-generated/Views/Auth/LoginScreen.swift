import SwiftUI
import AuthenticationServices

struct LoginScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var currentNonce: String?

    var body: some View {
        @Bindable var vm = authVM

        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("Wakee")
                            .font(.system(size: AppTheme.FontSize.xxl, weight: .extrabold))
                            .foregroundStyle(AppTheme.accentGradient)
                        Text("友達を起こそう")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }

                    Spacer().frame(height: 40)

                    // Auth buttons
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Google
                        Button(action: { Task { await authVM.signInWithGoogle() } }) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                Text("Googleでログイン")
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

                        // Apple
                        SignInWithAppleButton(.signIn) { request in
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

                        // Phone
                        Button(action: {
                            authVM.showPhoneModal = true
                            authVM.errorMessage = nil
                        }) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 18))
                                Text("電話番号でログイン")
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

                        // Email toggle
                        Button(action: {
                            withAnimation {
                                authVM.showEmailForm.toggle()
                                authVM.errorMessage = nil
                            }
                        }) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))
                                Text("メールでログイン")
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
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Email form
                    if authVM.showEmailForm {
                        emailForm
                    }

                    // Error message
                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.danger)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $vm.showPhoneModal) {
            phoneSheet
        }
    }

    // MARK: - Email Form
    private var emailForm: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Mode toggle
            Picker("", selection: Binding(
                get: { authVM.emailMode },
                set: { authVM.emailMode = $0 }
            )) {
                Text("ログイン").tag(AuthViewModel.EmailMode.login)
                Text("新規登録").tag(AuthViewModel.EmailMode.signup)
            }
            .pickerStyle(.segmented)

            if authVM.emailMode == .signup {
                TextField("表示名", text: Binding(
                    get: { authVM.displayName },
                    set: { authVM.displayName = $0 }
                ))
                .textFieldStyle(DarkTextFieldStyle())
            }

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

    // MARK: - Phone Sheet
    private var phoneSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    if authVM.verificationId == nil {
                        VStack(spacing: AppTheme.Spacing.md) {
                            Text("電話番号を入力")
                                .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)

                            TextField("090XXXXXXXX", text: Binding(
                                get: { authVM.phoneNumber },
                                set: { authVM.phoneNumber = $0 }
                            ))
                            .textFieldStyle(DarkTextFieldStyle())
                            .keyboardType(.phonePad)

                            GradientButton(
                                title: "SMS を送信",
                                isLoading: authVM.isLoading
                            ) {
                                Task { await authVM.sendPhoneVerification() }
                            }
                        }
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            Text("認証コードを入力")
                                .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)

                            TextField("6桁のコード", text: Binding(
                                get: { authVM.smsCode },
                                set: { authVM.smsCode = $0 }
                            ))
                            .textFieldStyle(DarkTextFieldStyle())
                            .keyboardType(.numberPad)

                            GradientButton(
                                title: "認証する",
                                isLoading: authVM.isLoading
                            ) {
                                Task { await authVM.verifyPhoneCode() }
                            }
                        }
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.danger)
                    }

                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        authVM.showPhoneModal = false
                        authVM.verificationId = nil
                        authVM.smsCode = ""
                        authVM.errorMessage = nil
                    }
                    .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Dark TextField Style
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                    .fill(AppTheme.Colors.surfaceVariant)
            )
            .foregroundColor(AppTheme.Colors.primary)
    }
}

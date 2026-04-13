import SwiftUI
import FirebaseAuth

struct ChangePasswordScreen: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resetIsLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Spacer().frame(height: AppTheme.Spacing.md)

                        SecureField(lang.l("password.current"), text: $currentPassword)
                            .textFieldStyle(DarkTextFieldStyle())

                        HStack {
                            Spacer()
                            Button {
                                Task { await sendReset() }
                            } label: {
                                if resetIsLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(AppTheme.Colors.accent)
                                } else {
                                    Text(lang.l("auth.forgot_password"))
                                        .font(.system(size: AppTheme.FontSize.sm))
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                            .disabled(resetIsLoading)
                        }

                        SecureField(lang.l("password.new"), text: $newPassword)
                            .textFieldStyle(DarkTextFieldStyle())

                        SecureField(lang.l("password.confirm"), text: $confirmPassword)
                            .textFieldStyle(DarkTextFieldStyle())

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.danger)
                        }

                        if let success = successMessage {
                            Text(success)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.accent)
                        }

                        GradientButton(
                            title: lang.l("password.change_btn"),
                            isLoading: isLoading,
                            disabled: currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty
                        ) {
                            Task { await changePassword() }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle(lang.l("settings.change_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.close")) { dismiss() }
                }
            }
        }
    }

    private func sendReset() async {
        resetIsLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let email = Auth.auth().currentUser?.email ?? ""
            try await AuthService.shared.sendPasswordReset(email: email)
            successMessage = lang.l("auth.reset_email_sent")
        } catch {
            errorMessage = error.localizedDescription
        }
        resetIsLoading = false
    }

    private func changePassword() async {
        errorMessage = nil
        successMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = lang.l("password.too_short")
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = lang.l("password.mismatch")
            return
        }

        isLoading = true
        do {
            try await AuthService.shared.reauthenticateWithPassword(currentPassword)
            try await AuthService.shared.changePassword(to: newPassword)
            successMessage = lang.l("password.change_success")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

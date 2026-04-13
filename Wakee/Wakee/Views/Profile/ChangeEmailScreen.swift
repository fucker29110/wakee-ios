import SwiftUI
import FirebaseAuth

struct ChangeEmailScreen: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let hasPassword = AuthService.shared.hasPasswordProvider

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Spacer().frame(height: AppTheme.Spacing.md)

                        // 現在のメールアドレス
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(lang.l("email.current"))
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.secondary)
                            Text(Auth.auth().currentUser?.email ?? "")
                                .font(.system(size: AppTheme.FontSize.md))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 新しいメールアドレス
                        TextField(lang.l("email.new"), text: $newEmail)
                            .textFieldStyle(DarkTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        // パスワード（パスワードプロバイダーがある場合のみ）
                        if hasPassword {
                            SecureField(lang.l("email.enter_password"), text: $currentPassword)
                                .textFieldStyle(DarkTextFieldStyle())
                        }

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
                            title: lang.l("email.change_btn"),
                            isLoading: isLoading,
                            disabled: newEmail.isEmpty || (hasPassword && currentPassword.isEmpty)
                        ) {
                            Task { await changeEmail() }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle(lang.l("settings.change_email"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.close")) { dismiss() }
                }
            }
        }
    }

    private func changeEmail() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            if hasPassword {
                try await AuthService.shared.reauthenticateWithPassword(currentPassword)
            }
            try await AuthService.shared.changeEmail(to: newEmail)
            successMessage = lang.l("email.change_success")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

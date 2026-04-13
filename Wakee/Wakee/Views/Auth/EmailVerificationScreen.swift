import SwiftUI
import FirebaseAuth

struct EmailVerificationScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()

                Image(systemName: "envelope.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.accentGradient)

                Text(lang.l("verify.title"))
                    .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)

                if let email = Auth.auth().currentUser?.email {
                    Text(lang.l("verify.sent_to", args: email))
                        .font(.system(size: AppTheme.FontSize.md))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(lang.l("verify.check_inbox"))
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: AppTheme.Spacing.md) {
                    if let success = successMessage {
                        Text(success)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.accent)
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.danger)
                    }

                    GradientButton(
                        title: lang.l("verify.done_btn"),
                        isLoading: false
                    ) {
                        Task { await authVM.checkEmailVerification() }
                    }

                    Button {
                        Task {
                            await authVM.resendVerification()
                            successMessage = lang.l("verify.resent")
                        }
                    } label: {
                        Text(lang.l("verify.resend"))
                            .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.accent)
                    }

                    Button {
                        authVM.signOut()
                    } label: {
                        Text(lang.l("verify.back"))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }
}

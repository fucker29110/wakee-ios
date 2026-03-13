import SwiftUI

struct SettingsScreen: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Logout
            VStack(spacing: 0) {
                Button(action: { authVM.signOut() }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(AppTheme.Colors.danger)
                        Text("ログアウト")
                            .foregroundColor(AppTheme.Colors.danger)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.BorderRadius.md)

            // App info
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Wakee")
                    .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                    .foregroundStyle(AppTheme.accentGradient)
                Text("Version 1.0.0")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            .padding(.top, AppTheme.Spacing.xl)

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

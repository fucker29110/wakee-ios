import SwiftUI
import UserNotifications

struct NotificationSettingsModal: View {
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accentGradient)

            Text(lang.l("dnd_modal.title"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
                .multilineTextAlignment(.center)

            Text(lang.l("dnd_modal.message"))
                .font(.system(size: AppTheme.FontSize.md))
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.md)

            Spacer()

            VStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    openNotificationSettings()
                    NotificationSettingsModal.markAsConfigured()
                    dismiss()
                } label: {
                    Text(lang.l("dnd_modal.open_settings"))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                .fill(AppTheme.accentGradient)
                        )
                }

                Button {
                    dismiss()
                } label: {
                    Text(lang.l("dnd_modal.later"))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Display Logic

    private static let configuredKey = "notificationSettingsConfigured"
    private static let launchCountKey = "notificationModalLaunchCount"

    static func markAsConfigured() {
        UserDefaults.standard.set(true, forKey: configuredKey)
    }

    /// Returns true if the modal should be shown (notification not fully authorized,
    /// not marked as configured, and launch count meets frequency).
    static func shouldShow() async -> Bool {
        if UserDefaults.standard.bool(forKey: configuredKey) {
            return false
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized {
            return false
        }

        // Increment launch counter and check frequency (every 3 launches)
        let count = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(count, forKey: launchCountKey)
        return count % 3 == 1 // Show on 1st, 4th, 7th, ... launch
    }
}

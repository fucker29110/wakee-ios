import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @Environment(\.openURL) private var openURL
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var notifSettings: NotificationSettings = NotificationSettings()
    @State private var showChangeEmail = false
    @State private var showChangePassword = false
    @State private var showFocusGuide = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Language selector
                VStack(spacing: 0) {
                    sectionTitle(lang.l("settings.language"))
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button(action: { lang.currentLanguage = language }) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "globe")
                                    .frame(width: 24)
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text(language.displayName)
                                    .foregroundColor(AppTheme.Colors.primary)
                                Spacer()
                                if lang.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, 10)
                        }
                        if language != AppLanguage.allCases.last {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Account Info
                VStack(spacing: 0) {
                    sectionTitle(lang.l("settings.account_info"))
                    settingsRow(icon: "envelope", title: lang.l("settings.change_email")) {
                        showChangeEmail = true
                    }
                    if AuthService.shared.hasPasswordProvider {
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "lock", title: lang.l("settings.change_password")) {
                            showChangePassword = true
                        }
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Notification Settings
                VStack(spacing: 0) {
                    sectionTitle(lang.l("settings.notification_settings"))
                    notifToggle(label: lang.l("settings.alarm_receive"), icon: "alarm", binding: $notifSettings.alarmReceived)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.messages"), icon: "message", binding: $notifSettings.messages)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.likes"), icon: "heart", binding: $notifSettings.likes)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.reposts"), icon: "arrow.2.squarepath", binding: $notifSettings.reposts)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.friend_requests"), icon: "person.badge.plus", binding: $notifSettings.friendRequests)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.reactions"), icon: "face.smiling", binding: $notifSettings.reactions)
                    Divider().padding(.leading, 48)
                    notifToggle(label: lang.l("settings.live_activity"), icon: "dot.radiowaves.left.and.right", binding: $notifSettings.liveActivity)
                    Divider().padding(.leading, 48)
                    settingsRow(icon: "moon.fill", title: lang.l("settings.focus_mode")) {
                        showFocusGuide = true
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Legal & Support
                VStack(spacing: 0) {
                    settingsRow(icon: "doc.text", title: lang.l("settings.terms")) {
                        openURL(URL(string: "https://tokyoforge.co/wakee/terms")!)
                    }
                    Divider().padding(.leading, 48)
                    settingsRow(icon: "shield", title: lang.l("settings.privacy")) {
                        openURL(URL(string: "https://tokyoforge.co/wakee/privacy")!)
                    }
                    Divider().padding(.leading, 48)
                    settingsRow(icon: "envelope", title: lang.l("settings.contact")) {
                        openURL(URL(string: "mailto:wakeecontact@tokyoforge.co")!)
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Danger zone
                VStack(spacing: 0) {
                    Button(action: { authVM.signOut() }) {
                        settingsLabel(icon: "rectangle.portrait.and.arrow.right", title: lang.l("settings.logout"), color: AppTheme.Colors.danger)
                    }
                    Divider().padding(.leading, 48)
                    Button(action: { showDeleteAlert = true }) {
                        settingsLabel(icon: "trash", title: lang.l("settings.delete_account"), color: AppTheme.Colors.danger)
                    }
                    .disabled(isDeleting)
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
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadNotifSettings() }
        .sheet(isPresented: $showChangeEmail) {
            ChangeEmailScreen()
                .environment(lang)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordScreen()
                .environment(lang)
        }
        .sheet(isPresented: $showFocusGuide) {
            FocusModeModal(uid: authVM.user?.uid ?? "")
                .environment(lang)
                .presentationDetents([.large])
        }
        .alert(lang.l("settings.delete_confirm"), isPresented: $showDeleteAlert) {
            Button(lang.l("common.cancel"), role: .cancel) {}
            Button(lang.l("settings.delete_btn"), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(lang.l("settings.delete_warning"))
        }
    }

    // MARK: - Components

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                .foregroundColor(AppTheme.Colors.secondary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xs)
    }

    private func notifToggle(label: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(AppTheme.Colors.primary)
            Text(label)
                .foregroundColor(AppTheme.Colors.primary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(AppTheme.Colors.accent)
                .onChange(of: binding.wrappedValue) { _, _ in
                    saveNotifSettings()
                }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 10)
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsLabel(icon: icon, title: title, color: AppTheme.Colors.primary)
        }
    }

    private func settingsLabel(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(color)
                .fontWeight(.semibold)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .padding(AppTheme.Spacing.md)
    }

    // MARK: - Data

    private func loadNotifSettings() {
        if let settings = authVM.user?.notificationSettings {
            notifSettings = settings
        }
    }

    private func saveNotifSettings() {
        guard let uid = authVM.user?.uid else { return }
        let data: [String: Any] = [
            "notificationSettings": [
                "alarmReceived": notifSettings.alarmReceived,
                "messages": notifSettings.messages,
                "likes": notifSettings.likes,
                "reposts": notifSettings.reposts,
                "friendRequests": notifSettings.friendRequests,
                "reactions": notifSettings.reactions,
                "liveActivity": notifSettings.liveActivity,
            ],
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        Task {
            try? await Firestore.firestore().collection("users").document(uid).updateData(data)
            authVM.user?.notificationSettings = notifSettings
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await Auth.auth().currentUser?.delete()
                await MainActor.run {
                    authVM.signOut()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    authVM.errorMessage = lang.l("settings.delete_failed")
                }
            }
        }
    }
}

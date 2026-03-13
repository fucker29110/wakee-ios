import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.openURL) private var openURL
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var notifSettings: NotificationSettings = NotificationSettings()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Notification Settings
                VStack(spacing: 0) {
                    sectionTitle("通知設定")
                    notifToggle(label: "アラーム受信", icon: "alarm", binding: $notifSettings.alarmReceived)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "メッセージ", icon: "message", binding: $notifSettings.messages)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "いいね", icon: "heart", binding: $notifSettings.likes)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "リポスト", icon: "arrow.2.squarepath", binding: $notifSettings.reposts)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "フレンド申請", icon: "person.badge.plus", binding: $notifSettings.friendRequests)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "リアクション", icon: "face.smiling", binding: $notifSettings.reactions)
                    Divider().padding(.leading, 48)
                    notifToggle(label: "ライブアクティビティ", icon: "dot.radiowaves.left.and.right", binding: $notifSettings.liveActivity)
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Legal & Support
                VStack(spacing: 0) {
                    settingsRow(icon: "doc.text", title: "利用規約") {
                        openURL(URL(string: "https://tokyoforge.co/wakee/terms")!)
                    }
                    Divider().padding(.leading, 48)
                    settingsRow(icon: "shield", title: "プライバシーポリシー") {
                        openURL(URL(string: "https://tokyoforge.co/wakee/privacy")!)
                    }
                    Divider().padding(.leading, 48)
                    settingsRow(icon: "envelope", title: "お問い合わせ") {
                        openURL(URL(string: "mailto:wakeecontact@tokyoforge.co")!)
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.BorderRadius.md)

                // Danger zone
                VStack(spacing: 0) {
                    Button(action: { authVM.signOut() }) {
                        settingsLabel(icon: "rectangle.portrait.and.arrow.right", title: "ログアウト", color: AppTheme.Colors.danger)
                    }
                    Divider().padding(.leading, 48)
                    Button(action: { showDeleteAlert = true }) {
                        settingsLabel(icon: "trash", title: "アカウント削除", color: AppTheme.Colors.danger)
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
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadNotifSettings() }
        .alert("アカウントを削除しますか？", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("この操作は取り消せません。すべてのデータが削除されます。")
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
                    authVM.errorMessage = "アカウント削除に失敗しました。再ログイン後にもう一度お試しください。"
                }
            }
        }
    }
}

import SwiftUI

struct RepostSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    let activity: Activity
    let userMap: [String: ActivityService.UserInfo]
    let myFriendUids: [String]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var isSending = false

    private var actorName: String {
        userMap[activity.actorUid]?.displayName ?? lang.l("common.user")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    // Original post preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text(actorName)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.primary)
                            .font(.system(size: AppTheme.FontSize.sm))
                        if let message = activity.message, !message.isEmpty {
                            Text(message)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.BorderRadius.md)

                    TextField(lang.l("repost.add_comment"), text: $comment)
                        .textFieldStyle(DarkTextFieldStyle())

                    GradientButton(title: lang.l("repost.btn")) {
                        repost()
                    }
                    .disabled(isSending)

                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
            }
            .navigationTitle(lang.l("repost.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .overlay {
            if isSending {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .scaleEffect(1.2)
            }
        }
    }

    private func repost() {
        guard let uid = authVM.user?.uid else { return }
        isSending = true
        let visibleTo = Array(Set(myFriendUids + [uid]))
        let originalMessage = activity.message
        Task {
            do {
                let repostDocId = try await ActivityService.shared.record(
                    type: .repost,
                    actorUid: uid,
                    targetUid: activity.actorUid,
                    time: activity.time,
                    displayMessage: originalMessage,
                    visibleTo: visibleTo,
                    repostSourceId: activity.id,
                    repostComment: comment.isEmpty ? nil : comment
                )

                if activity.actorUid != uid {
                    let username = authVM.user?.username ?? ""
                    let displayName = authVM.user?.displayName ?? ""
                    try? await NotificationHistoryService.shared.create(
                        recipientUid: activity.actorUid,
                        type: .repost,
                        title: lang.l("repost.notification", args: username),
                        body: "",
                        senderUid: uid,
                        senderName: displayName,
                        relatedId: repostDocId,
                        titleKey: "repost.notification",
                        titleArgs: [username]
                    )
                }

                dismiss()
                onDone()
            } catch {
                print("Repost error: \(error)")
                isSending = false
            }
        }
    }
}

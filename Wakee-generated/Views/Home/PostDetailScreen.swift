import SwiftUI
import FirebaseFirestore

struct PostDetailScreen: View {
    let activityId: String
    let actorName: String
    let targetName: String?

    @Environment(AuthViewModel.self) private var authVM
    @State private var activity: Activity?
    @State private var comments: [Comment] = []
    @State private var authorNames: [String: String] = [:]
    @State private var text = ""
    @State private var isSending = false

    @State private var activityListener: ListenerRegistration?
    @State private var commentsListener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    // Activity detail
                    if let activity {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                AvatarView(name: actorName, photoURL: nil, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(actorName)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.Colors.primary)
                                    Text(TimeUtils.timeAgo(from: activity.createdDate))
                                        .font(.system(size: AppTheme.FontSize.xs))
                                        .foregroundColor(AppTheme.Colors.secondary)
                                }
                            }

                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "alarm.fill")
                                    .foregroundColor(AppTheme.Colors.accent)
                                Text(TimeUtils.formatAlarmTime(activity.time))
                                    .foregroundColor(AppTheme.Colors.primary)
                                if let targetName {
                                    Text("→ \(targetName)")
                                        .foregroundColor(AppTheme.Colors.secondary)
                                }
                            }
                            .font(.system(size: AppTheme.FontSize.sm))

                            if let message = activity.displayMessage ?? activity.message, !message.isEmpty {
                                Text(message)
                                    .font(.system(size: AppTheme.FontSize.md))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.BorderRadius.md)
                    }

                    // Comments
                    if !comments.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in
                                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                    AvatarView(
                                        name: authorNames[comment.authorId] ?? "ユーザー",
                                        photoURL: nil,
                                        size: 32
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(authorNames[comment.authorId] ?? "ユーザー")
                                            .fontWeight(.semibold)
                                            .font(.system(size: AppTheme.FontSize.sm))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        Text(comment.text)
                                            .font(.system(size: AppTheme.FontSize.sm))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        Text(TimeUtils.timeAgo(from: comment.createdDate))
                                            .font(.system(size: AppTheme.FontSize.xs))
                                            .foregroundColor(AppTheme.Colors.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, AppTheme.Spacing.sm)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }

            // Comment input
            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("コメントを入力...", text: $text)
                    .textFieldStyle(DarkTextFieldStyle())

                Button(action: sendComment) {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.Colors.secondary : .white)
                    }
                }
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(AppTheme.Colors.accent)
                )
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(AppTheme.Spacing.sm)
            .background(AppTheme.Colors.surface)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("投稿詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupListeners() }
        .onDisappear {
            activityListener?.remove()
            commentsListener?.remove()
        }
    }

    private func setupListeners() {
        activityListener = ActivityService.shared.subscribeActivity(activityId: activityId) { activity in
            self.activity = activity
        }
        commentsListener = CommentService.shared.subscribeComments(activityId: activityId) { comments in
            self.comments = comments
            let uids = comments.map(\.authorId)
            Task {
                let names = await ActivityService.shared.getDisplayNames(uids)
                await MainActor.run { self.authorNames = names }
            }
        }
    }

    private func sendComment() {
        guard let uid = authVM.user?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        text = ""
        Task {
            try? await CommentService.shared.addComment(
                activityId: activityId,
                authorId: uid,
                text: trimmed,
                visibilityBasis: .actor_friends
            )
            await MainActor.run { isSending = false }
        }
    }
}

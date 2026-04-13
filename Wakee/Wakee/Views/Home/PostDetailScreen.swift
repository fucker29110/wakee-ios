import SwiftUI
import FirebaseFirestore

struct PostDetailScreen: View {
    let activityId: String
    let actorName: String
    let targetName: String?

    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var activity: Activity?
    @State private var sourceActivity: Activity?
    @State private var userMap: [String: ActivityService.UserInfo] = [:]
    @State private var comments: [Comment] = []
    @State private var authorNames: [String: String] = [:]
    @State private var text = ""
    @State private var isSending = false
    @State private var showProfile = false
    @State private var profileUid = ""
    @State private var reportTarget: Activity?
    @FocusState private var isInputFocused: Bool

    @State private var activityListener: ListenerRegistration?
    @State private var commentsListener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let activity {
                            FeedItemView(
                                activity: activity,
                                userMap: userMap,
                                activityLabel: activity.feedLabel,
                                activityIcon: activity.feedIcon,
                                sourceActivity: sourceActivity,
                                onTap: nil,
                                onRepostTap: nil,
                                onLikeTap: {
                                    guard let user = authVM.user else { return }
                                    Task { try? await LikeService.shared.toggleLike(activityId: activityId, userId: user.uid, senderUsername: user.username, senderName: user.displayName) }
                                },
                                isLiked: activity.likedBy?.contains(authVM.user?.uid ?? "") == true,
                                onTargetProfileTap: activity.targetUid.map { uid in
                                    {
                                        if DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                            profileUid = uid; showProfile = true
                                        }
                                    }
                                },
                                onActorProfileTap: {
                                    if DeepLinkManager.shared.navigateToProfile(uid: activity.actorUid, myUid: authVM.user?.uid) {
                                        profileUid = activity.actorUid
                                        showProfile = true
                                    }
                                },
                                onSourceActorProfileTap: {
                                    let uid = sourceActivity?.actorUid ?? activity.targetUid ?? ""
                                    if !uid.isEmpty, DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                        profileUid = uid
                                        showProfile = true
                                    }
                                },
                                onSourceTargetProfileTap: {
                                    if let uid = sourceActivity?.targetUid,
                                       DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                        profileUid = uid
                                        showProfile = true
                                    }
                                },
                                onReportTap: activity.actorUid != authVM.user?.uid ? {
                                    reportTarget = activity
                                } : nil
                            )
                        }

                        // Comments section
                        commentsSection

                        // スクロール先アンカー
                        Color.clear
                            .frame(height: 1)
                            .id("commentsBottom")
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("commentsBottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: comments.count) { _, _ in
                    if isInputFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("commentsBottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()
                .overlay(AppTheme.Colors.border)

            // Comment input
            commentInputBar
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("post.detail"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showProfile) {
            FriendProfileScreen(uid: profileUid)
        }
        .sheet(item: $reportTarget) { target in
            ReportReasonSheet(activity: target, reporterId: authVM.user?.uid ?? "") {
                reportTarget = nil
            }
            .environment(lang)
        }
        .onAppear { setupListeners() }
        .onDisappear {
            activityListener?.remove()
            commentsListener?.remove()
        }
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !comments.isEmpty {
                // Section header
                Text(lang.l("post.comments"))
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.sm)

                ForEach(comments) { comment in
                    commentRow(comment)
                }
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AvatarView(
                name: authorNames[comment.authorId] ?? lang.l("common.user"),
                photoURL: nil,
                size: 36
            )
            .onTapGesture {
                if DeepLinkManager.shared.navigateToProfile(uid: comment.authorId, myUid: authVM.user?.uid) {
                    profileUid = comment.authorId
                    showProfile = true
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(authorNames[comment.authorId] ?? lang.l("common.user"))
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    Text(TimeUtils.timeAgo(from: comment.createdDate))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                Text(comment.text)
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - Input Bar

    private var commentInputBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField(lang.l("post.comment_input"), text: $text)
                .font(.system(size: AppTheme.FontSize.sm))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.Colors.surfaceVariant)
                )
                .foregroundColor(AppTheme.Colors.primary)
                .focused($isInputFocused)

            Button(action: sendComment) {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        canSend
                            ? AppTheme.accentGradient
                            : LinearGradient(colors: [AppTheme.Colors.surfaceVariant], startPoint: .leading, endPoint: .trailing)
                    )
                )
            }
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .padding(.bottom, 70)
        .background(AppTheme.Colors.surface)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Data

    private func setupListeners() {
        activityListener = ActivityService.shared.subscribeActivity(activityId: activityId) { activity in
            self.activity = activity
            guard let activity else { return }
            // userMap を構築
            var uids = [activity.actorUid]
            if let targetUid = activity.targetUid { uids.append(targetUid) }

            // リポストの場合、元投稿を取得
            if activity.type == .repost, let sourceId = activity.repostSourceId {
                Task {
                    let src = try? await ActivityService.shared.getActivity(activityId: sourceId)
                    await MainActor.run { self.sourceActivity = src }
                    if let src {
                        var srcUids = [src.actorUid]
                        if let targetUid = src.targetUid { srcUids.append(targetUid) }
                        let srcInfos = await ActivityService.shared.getUserInfoByUids(srcUids)
                        await MainActor.run {
                            for (uid, info) in srcInfos {
                                self.userMap[uid] = info
                            }
                        }
                    }
                }
            }

            Task {
                let infos = await ActivityService.shared.getUserInfoByUids(uids)
                await MainActor.run {
                    for (uid, info) in infos {
                        self.userMap[uid] = info
                    }
                }
            }
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
        guard let user = authVM.user else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        text = ""
        Task {
            try? await CommentService.shared.addComment(
                activityId: activityId,
                authorId: user.uid,
                text: trimmed,
                visibilityBasis: .actor_friends,
                senderUsername: user.username,
                senderName: user.displayName,
                activityActorUid: activity?.actorUid ?? ""
            )
            await MainActor.run { isSending = false }
        }
    }
}

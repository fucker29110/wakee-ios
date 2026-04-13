import SwiftUI

struct ProfileScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var profileVM = ProfileViewModel()
    @State private var selectedActivity: Activity?
    @State private var showTargetProfile = false
    @State private var targetProfileUid: String = ""
    @State private var reportTarget: Activity?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                if let user = authVM.user {
                    // Profile card
                    VStack(spacing: AppTheme.Spacing.md) {
                        AvatarView(name: user.displayName, photoURL: user.photoURL, size: 80)

                        Text(user.displayName)
                            .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text("@\(user.username)")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.primary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Stats
                    HStack(spacing: AppTheme.Spacing.xl) {
                        NavigationLink {
                            FriendsListScreen(initialTab: 1)
                        } label: {
                            statItem(value: "\(profileVM.friendCount)", label: lang.l("profile.friends"))
                        }
                        .buttonStyle(.plain)

                        statItem(value: "\(profileVM.wakeUpSentCount)", label: lang.l("profile.woke_others"))
                        statItem(value: "\(profileVM.wokeUpCount)", label: lang.l("profile.woken_by"))
                        statItem(value: "\(profileVM.failedWakeUpCount)", label: lang.l("profile.failed_wakeup"))
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.BorderRadius.md)

                    // Actions
                    HStack(spacing: AppTheme.Spacing.md) {
                        NavigationLink {
                            ProfileEditScreen()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text(lang.l("profile.edit"))
                            }
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            )
                        }

                        NavigationLink {
                            SettingsScreen()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                Text(lang.l("profile.settings"))
                            }
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.md)

            // Timeline
            VStack(alignment: .leading, spacing: 0) {
                Text(lang.l("profile.activity"))
                    .font(.system(size: AppTheme.FontSize.md, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.bottom, AppTheme.Spacing.xs)
            }

            if profileVM.isLoadingActivities {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .padding(.top, 20)
            } else {
                let timelineActivities = profileVM.activities.filter { $0.type != .sent }
                if timelineActivities.isEmpty {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "clock")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text(lang.l("profile.no_activities"))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.xl)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(timelineActivities) { activity in
                        FeedItemView(
                            activity: activity,
                            userMap: profileVM.userMap,
                            activityLabel: activity.feedLabel,
                            activityIcon: activity.feedIcon,
                            sourceActivity: activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] },
                            onTap: {
                                selectedActivity = activity
                            },
                            onLikeTap: {
                                guard let user = authVM.user else { return }
                                Task { try? await LikeService.shared.toggleLike(activityId: activity.id, userId: user.uid, senderUsername: user.username, senderName: user.displayName) }
                            },
                            isLiked: activity.likedBy?.contains(authVM.user?.uid ?? "") == true,
                            onTargetProfileTap: {
                                if let uid = activity.targetUid,
                                   DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                    targetProfileUid = uid
                                    showTargetProfile = true
                                }
                            },
                            onActorProfileTap: {
                                if DeepLinkManager.shared.navigateToProfile(uid: activity.actorUid, myUid: authVM.user?.uid) {
                                    targetProfileUid = activity.actorUid
                                    showTargetProfile = true
                                }
                            },
                            onSourceActorProfileTap: {
                                let src = activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] }
                                let uid = src?.actorUid ?? activity.targetUid ?? ""
                                if !uid.isEmpty, DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                    targetProfileUid = uid
                                    showTargetProfile = true
                                }
                            },
                            onSourceTargetProfileTap: {
                                let src = activity.repostSourceId.flatMap { profileVM.sourceActivities[$0] }
                                if let uid = src?.targetUid,
                                   DeepLinkManager.shared.navigateToProfile(uid: uid, myUid: authVM.user?.uid) {
                                    targetProfileUid = uid
                                    showTargetProfile = true
                                }
                            },
                            onReportTap: activity.actorUid != authVM.user?.uid ? {
                                reportTarget = activity
                            } : nil,
                            showPrivateBadge: true
                        )
                    }
                }
            }
            }
        }
        .refreshable {
            guard let uid = authVM.user?.uid else { return }
            await profileVM.refresh(uid: uid)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("profile.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedActivity) { activity in
            let actorName = profileVM.userMap[activity.actorUid]?.displayName ?? lang.l("common.user")
            let targetName = activity.targetUid.flatMap { profileVM.userMap[$0]?.displayName }
            PostDetailScreen(activityId: activity.id, actorName: actorName, targetName: targetName)
        }
        .navigationDestination(isPresented: $showTargetProfile) {
            FriendProfileScreen(uid: targetProfileUid)
        }
        .sheet(item: $reportTarget) { target in
            ReportReasonSheet(activity: target, reporterId: authVM.user?.uid ?? "") {
                reportTarget = nil
            }
            .environment(lang)
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            profileVM.subscribe(uid: uid, isOwnProfile: true)
        }
        .onDisappear { profileVM.unsubscribe() }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                .foregroundColor(AppTheme.Colors.accent)
            Text(label)
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .frame(maxWidth: .infinity)
    }

}

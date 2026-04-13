import SwiftUI
import AVFoundation

struct FeedItemView: View {
    let activity: Activity
    let userMap: [String: ActivityService.UserInfo]
    let activityLabel: String
    let activityIcon: String
    var sourceActivity: Activity?
    var onTap: (() -> Void)?
    var onRepostTap: (() -> Void)?
    var onLikeTap: (() -> Void)?
    var isLiked: Bool = false
    var onTargetProfileTap: (() -> Void)?
    var onActorProfileTap: (() -> Void)?
    var onSourceActorProfileTap: (() -> Void)?
    var onSourceTargetProfileTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    var onReportTap: (() -> Void)?
    var showPrivateBadge: Bool = false

    @State private var isMessageExpanded = false
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var localIsLiked: Bool?
    @Environment(LanguageManager.self) private var lang

    private var effectiveIsLiked: Bool {
        localIsLiked ?? isLiked
    }

    private var effectiveLikeCount: Int {
        let serverCount = activity.likeCount ?? 0
        guard let local = localIsLiked, local != isLiked else {
            return serverCount
        }
        return local ? serverCount + 1 : max(0, serverCount - 1)
    }

    private var isRepost: Bool { activity.type == .repost }

    // MARK: - ユーザー情報ヘルパー

    private func username(for uid: String) -> String {
        let info = userMap[uid]
        let name = info?.username ?? ""
        return name.isEmpty ? (info?.displayName ?? lang.l("common.user")) : name
    }

    private func photoURL(for uid: String) -> String? {
        userMap[uid]?.photoURL
    }

    private var actorUsername: String { username(for: activity.actorUid) }
    private var actorPhotoURL: String? { photoURL(for: activity.actorUid) }

    private var targetUsername: String? {
        guard let uid = activity.targetUid else { return nil }
        return username(for: uid)
    }

    private var messageText: String? {
        guard let msg = activity.message, !msg.isEmpty else { return nil }
        return msg
    }

    var body: some View {
        Group {
            if isRepost {
                repostBody
            } else {
                normalBody
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#1F1F1F"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - 通常の投稿レイアウト

    private var normalBody: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AvatarView(name: actorUsername, photoURL: actorPhotoURL, size: 44)
                .onTapGesture { onActorProfileTap?() }

            VStack(alignment: .leading, spacing: 4) {
                // タップで詳細遷移するエリア（actionButtonsは含めない）
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(actorUsername)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.primary)
                        Text(activityLabel)
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .font(.system(size: AppTheme.FontSize.md))
                    .lineLimit(1)

                    if showPrivateBadge && activity.isPrivate == true {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text(lang.l("feed.private"))
                                .font(.system(size: AppTheme.FontSize.xs))
                        }
                        .foregroundColor(AppTheme.Colors.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(AppTheme.Colors.surface)
                        )
                    }

                    HStack(spacing: 4) {
                        Image(systemName: activityIcon)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.accent)
                        Text(TimeUtils.formatAlarmTime(activity.time))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        Text("·")
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text(TimeUtils.timeAgo(from: activity.createdDate))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        if let target = targetUsername {
                            Text("by")
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.secondary)
                            Text(target)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.Colors.accent)
                                .onTapGesture { onTargetProfileTap?() }
                        }
                    }

                    // メッセージバブル
                    if let msg = messageText {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    // ボイスメモ再生ボタン
                    if let url = activity.audioURL, !url.isEmpty {
                        Button {
                            toggleAudio(url: url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                    .font(.system(size: 12))
                                Text(isPlayingAudio ? lang.l("common.stop") : lang.l("feed.voice_message"))
                                    .font(.system(size: AppTheme.FontSize.xs))
                            }
                            .foregroundColor(AppTheme.Colors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(AppTheme.Colors.accent.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }

                actionButtons
            }

            Spacer()
        }
    }

    // MARK: - リポスト表示レイアウト（Twitter/X風）

    private var repostBody: some View {
        let src = sourceActivity
        let srcActorUid = src?.actorUid ?? activity.targetUid ?? ""
        let srcActorName = username(for: srcActorUid)
        let srcActorPhoto = photoURL(for: srcActorUid)
        let srcTargetName: String? = src?.targetUid.map { username(for: $0) }
        let srcIcon = src?.type.icon ?? activityIcon
        let srcLabel = src?.type.label ?? ""
        let srcTime = src?.time ?? activity.time
        let srcCreatedDate = src?.createdDate ?? activity.createdDate
        let srcMessage = src?.message ?? activity.displayMessage

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // 🔁 user_hesx がリポスト
            HStack(spacing: 4) {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 12))
                Text(lang.l("feed.reposted_by", args: actorUsername))
                    .font(.system(size: AppTheme.FontSize.xs))
            }
            .foregroundColor(AppTheme.Colors.secondary)
            .onTapGesture { onActorProfileTap?() }

            // リポストコメント（アバター + 吹き出し）
            if let comment = activity.repostComment, !comment.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    AvatarView(name: actorUsername, photoURL: actorPhotoURL, size: 28)
                        .onTapGesture { onActorProfileTap?() }
                    Text(comment)
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.Colors.surface)
                        )
                }
            }

            // 元投稿カード（normalBody と同じ順番）
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                AvatarView(name: srcActorName, photoURL: srcActorPhoto, size: 32)
                    .onTapGesture { onSourceActorProfileTap?() }

                VStack(alignment: .leading, spacing: 4) {
                    // 名前 + ラベル（同一行）
                    if !srcLabel.isEmpty {
                        HStack(spacing: 4) {
                            Text(srcActorName)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.primary)
                                .onTapGesture { onSourceActorProfileTap?() }
                            Text(srcLabel)
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        .font(.system(size: AppTheme.FontSize.sm))
                        .lineLimit(1)
                    } else {
                        Text(srcActorName)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.primary)
                            .onTapGesture { onSourceActorProfileTap?() }
                    }

                    // 時刻 · 経過時間 · by ターゲット（同一行）
                    HStack(spacing: 4) {
                        Image(systemName: srcIcon)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.accent)
                        Text(TimeUtils.formatAlarmTime(srcTime))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text("·")
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text(TimeUtils.timeAgo(from: srcCreatedDate))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)

                        if let targetName = srcTargetName {
                            Text("by")
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.secondary)
                            Text(targetName)
                                .font(.system(size: AppTheme.FontSize.sm))
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.Colors.accent)
                                .onTapGesture { onSourceTargetProfileTap?() }
                        }
                    }

                    // 元投稿のメッセージ
                    if let msg = srcMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.BorderRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                    .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // アクションボタン（カードの外）
            actionButtons
        }
    }

    // MARK: - アクションボタン（共通）

    private var actionButtons: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 14))
                if let count = activity.commentCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: AppTheme.FontSize.sm))
                }
            }
            .foregroundColor(AppTheme.Colors.secondary)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            Button(action: { onRepostTap?() }) {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button(action: {
                localIsLiked = !effectiveIsLiked
                onLikeTap?()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: effectiveIsLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                    if effectiveLikeCount > 0 {
                        Text("\(effectiveLikeCount)")
                            .font(.system(size: AppTheme.FontSize.sm))
                    }
                }
                .foregroundColor(effectiveIsLiked ? AppTheme.Colors.accent : AppTheme.Colors.secondary)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .onChange(of: isLiked) { _, newValue in
                if localIsLiked == newValue {
                    localIsLiked = nil
                }
            }

            Spacer()

            if let onReportTap {
                Button(action: onReportTap) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if let onDeleteTap {
                Button(action: onDeleteTap) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.secondary)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Audio playback

    private func toggleAudio(url: String) {
        if isPlayingAudio {
            audioPlayer?.pause()
            isPlayingAudio = false
        } else {
            guard let audioUrl = URL(string: url) else { return }
            let player = AVPlayer(url: audioUrl)
            audioPlayer = player
            isPlayingAudio = true
            player.play()

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                isPlayingAudio = false
            }
        }
    }
}

import SwiftUI

struct StoryRow: View {
    let myStory: Story?
    let stories: [Story]
    let userMap: [String: ActivityService.UserInfo]
    let myUid: String
    let onCreateTap: () -> Void
    let onStoryTap: (Story) -> Void
    var onProfileTap: ((String) -> Void)?
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
                // My story / create
                myStoryItem

                // Friend stories
                ForEach(stories) { story in
                    storyItem(story: story)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, 36) // 吹き出し用の上部余白
            .padding(.bottom, AppTheme.Spacing.sm)
        }
        .background(AppTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#1F1F1F"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var myStoryItem: some View {
        Button(action: onCreateTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if let myStory {
                        storyCircle(
                            name: lang.l("story.me"),
                            photoURL: userMap[myUid]?.photoURL,
                            hasUnread: false,
                            text: myStory.text
                        )
                    } else {
                        Circle()
                            .fill(AppTheme.Colors.surfaceVariant)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.accent)
                            )
                    }

                    if myStory == nil {
                        Circle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                Text(myStory != nil ? lang.l("story.me") : lang.l("story.post_btn"))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func storyItem(story: Story) -> some View {
        let name = userMap[story.authorUid]?.displayName ?? lang.l("common.user")
        let photoURL = userMap[story.authorUid]?.photoURL
        let hasRead = story.readBy.contains(myUid)

        return Button(action: { onStoryTap(story) }) {
            VStack(spacing: 4) {
                storyCircle(name: name, photoURL: photoURL, hasUnread: !hasRead, text: story.text)

                Text(name)
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
    }

    private func storyCircle(name: String, photoURL: String?, hasUnread: Bool, text: String) -> some View {
        let displayText: String? = if text.isEmpty {
            nil
        } else if text.count <= 8 {
            text
        } else {
            String(text.prefix(8)) + "..."
        }

        return VStack(spacing: 2) {
            // 吹き出し
            if let displayText {
                VStack(spacing: 0) {
                    Text(displayText)
                        .font(.system(size: AppTheme.FontSize.xs, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.surface)
                        )

                    // 下向き三角
                    Triangle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 10, height: 6)
                }
            } else {
                // 吹き出しなしの場合のスペーサー（高さ揃え）
                Color.clear.frame(height: 0)
            }

            // アイコン
            ZStack {
                Circle()
                    .strokeBorder(
                        hasUnread ? AppTheme.accentGradient : LinearGradient(colors: [AppTheme.Colors.surfaceVariant], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)

                AvatarView(name: name, photoURL: photoURL, size: 52)
            }
        }
    }
}

// MARK: - Triangle Shape
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

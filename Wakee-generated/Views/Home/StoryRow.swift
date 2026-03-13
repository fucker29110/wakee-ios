import SwiftUI

struct StoryRow: View {
    let myStory: Story?
    let stories: [Story]
    let userMap: [String: ActivityService.UserInfo]
    let myUid: String
    let onCreateTap: () -> Void
    let onStoryTap: (Story) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.md) {
                // My story / create
                myStoryItem

                // Friend stories
                ForEach(stories) { story in
                    storyItem(story: story)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
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
                            name: "自分",
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

                Text(myStory != nil ? "自分" : "投稿")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func storyItem(story: Story) -> some View {
        Button(action: { onStoryTap(story) }) {
            VStack(spacing: 4) {
                let name = userMap[story.authorUid]?.displayName ?? "ユーザー"
                let photoURL = userMap[story.authorUid]?.photoURL
                let hasRead = story.readBy.contains(myUid)

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

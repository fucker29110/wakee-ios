import SwiftUI

struct StoryViewModal: View {
    let story: Story
    let authorName: String
    let authorPhotoURL: String?
    let isMyStory: Bool
    let onRead: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editText: String

    init(story: Story, authorName: String, authorPhotoURL: String?, isMyStory: Bool,
         onRead: @escaping () -> Void, onEdit: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.story = story
        self.authorName = authorName
        self.authorPhotoURL = authorPhotoURL
        self.isMyStory = isMyStory
        self.onRead = onRead
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._editText = State(initialValue: story.text)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    // Author info
                    HStack(spacing: AppTheme.Spacing.sm) {
                        AvatarView(name: authorName, photoURL: authorPhotoURL, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authorName)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.primary)
                            Text(TimeUtils.timeAgo(from: story.createdDate))
                                .font(.system(size: AppTheme.FontSize.xs))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        Spacer()
                    }

                    // Story content
                    if isEditing {
                        TextEditor(text: $editText)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(AppTheme.Spacing.sm)
                            .frame(minHeight: 100)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                    .fill(AppTheme.Colors.surfaceVariant)
                            )

                        HStack {
                            Button("キャンセル") {
                                isEditing = false
                                editText = story.text
                            }
                            .foregroundColor(AppTheme.Colors.secondary)

                            Spacer()

                            GradientButton(title: "保存") {
                                onEdit(editText.trimmingCharacters(in: .whitespaces))
                                isEditing = false
                                dismiss()
                            }
                            .frame(width: 100)
                        }
                    } else {
                        Text(story.text)
                            .font(.system(size: AppTheme.FontSize.lg))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppTheme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.Colors.surface)
                            )
                    }

                    if isMyStory && !isEditing {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Button(action: { isEditing = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("編集")
                                }
                                .foregroundColor(AppTheme.Colors.accent)
                            }

                            Button(action: {
                                onDelete()
                                dismiss()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("削除")
                                }
                                .foregroundColor(AppTheme.Colors.danger)
                            }
                        }

                        Text("閲覧: \(story.readBy.count)人")
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }

                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { onRead() }
    }
}

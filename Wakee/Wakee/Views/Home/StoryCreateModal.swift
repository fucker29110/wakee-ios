import SwiftUI

struct StoryCreateModal: View {
    let existingText: String?
    let onPost: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang
    @State private var text: String
    private let maxLength = 140

    init(existingText: String?, onPost: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.existingText = existingText
        self.onPost = onPost
        self.onDelete = onDelete
        self._text = State(initialValue: existingText ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    Text(existingText != nil ? lang.l("story.edit") : lang.l("story.today"))
                        .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(AppTheme.Spacing.sm)
                        .frame(height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                .fill(AppTheme.Colors.surfaceVariant)
                        )
                        .onChange(of: text) { _, newValue in
                            if newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
                        }

                    HStack {
                        Text("\(text.count)/\(maxLength)")
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                        Spacer()
                    }

                    GradientButton(
                        title: existingText != nil ? lang.l("story.update") : lang.l("story.post"),
                        disabled: text.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        onPost(text.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }

                    if existingText != nil {
                        Button(action: {
                            onDelete()
                            dismiss()
                        }) {
                            Text(lang.l("story.delete"))
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.danger)
                        }
                    }

                    Spacer()
                }
                .padding(AppTheme.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.close")) { dismiss() }
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

import SwiftUI

struct ReportReasonSheet: View {
    let activity: Activity
    let reporterId: String
    var onDismiss: () -> Void

    @State private var selectedReason: String?
    @State private var isSubmitting = false
    @State private var showCompletion = false
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang

    private var reasons: [String] {
        [
            lang.l("report.spam"),
            lang.l("report.inappropriate"),
            lang.l("report.harassment"),
            lang.l("report.other")
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                if showCompletion {
                    // 送信完了画面
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.accent)

                        Text(lang.l("report.sent"))
                            .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)

                        Text(lang.l("report.thanks"))
                            .font(.system(size: AppTheme.FontSize.md))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .multilineTextAlignment(.center)

                        Spacer()

                        GradientButton(title: "OK") {
                            dismiss()
                            onDismiss()
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                } else {
                    // 理由選択画面
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Text(lang.l("report.select_reason"))
                            .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.top, AppTheme.Spacing.md)

                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(reasons, id: \.self) { reason in
                                Button {
                                    selectedReason = reason
                                } label: {
                                    HStack {
                                        Text(reason)
                                            .font(.system(size: AppTheme.FontSize.md))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        Spacer()
                                        if selectedReason == reason {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppTheme.Colors.accent)
                                        }
                                    }
                                    .padding(AppTheme.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .fill(selectedReason == reason ? AppTheme.Colors.accent.opacity(0.1) : AppTheme.Colors.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                            .stroke(selectedReason == reason ? AppTheme.Colors.accent : AppTheme.Colors.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)

                        Spacer()

                        Button {
                            submitReport()
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(lang.l("report.submit"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(selectedReason != nil ? AppTheme.Colors.danger : AppTheme.Colors.surfaceVariant)
                            )
                        }
                        .disabled(selectedReason == nil || isSubmitting)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle(showCompletion ? "" : lang.l("report.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showCompletion {
                        Button(lang.l("common.cancel")) {
                            dismiss()
                            onDismiss()
                        }
                    }
                }
            }
        }
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        Task {
            do {
                try await ReportService.shared.submitReport(
                    reporterId: reporterId,
                    targetUserId: activity.actorUid,
                    postId: activity.id,
                    reason: reason
                )
                await MainActor.run {
                    isSubmitting = false
                    withAnimation { showCompletion = true }
                }
            } catch {
                await MainActor.run { isSubmitting = false }
                print("Report submission error: \(error)")
            }
        }
    }
}

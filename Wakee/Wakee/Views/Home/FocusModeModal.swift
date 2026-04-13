import SwiftUI

struct FocusModeModal: View {
    let uid: String
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var hasOpenedSettings = false
    @State private var currentStep = 0

    private static let configuredKeyPrefix = "focusModeConfigured_"
    private static let launchCountKeyPrefix = "focusModalLaunchCount_"

    private struct GuideStep {
        let imageJa: String
        let imageEn: String
        let titleKey: String
        let descKey: String
    }

    private var steps: [GuideStep] {
        [
            GuideStep(imageJa: "FocusGuide1", imageEn: "FocusGuideEn1", titleKey: "focus_guide.step1_title", descKey: "focus_guide.step1_desc"),
            GuideStep(imageJa: "FocusGuide2", imageEn: "FocusGuideEn2", titleKey: "focus_guide.step2_title", descKey: "focus_guide.step2_desc"),
            GuideStep(imageJa: "FocusGuide3", imageEn: "FocusGuideEn3", titleKey: "focus_guide.step3_title", descKey: "focus_guide.step3_desc"),
            GuideStep(imageJa: "FocusGuide4", imageEn: "FocusGuideEn4", titleKey: "focus_guide.step4_title", descKey: "focus_guide.step4_desc"),
            GuideStep(imageJa: "FocusGuide5", imageEn: "FocusGuideEn5", titleKey: "focus_guide.step5_title", descKey: "focus_guide.step5_desc"),
            GuideStep(imageJa: "FocusGuide6", imageEn: "FocusGuideEn6", titleKey: "focus_guide.step6_title", descKey: "focus_guide.step6_desc"),
            GuideStep(imageJa: "FocusGuide7", imageEn: "FocusGuideEn7", titleKey: "focus_guide.step7_title", descKey: "focus_guide.step7_desc"),
        ]
    }

    private func imageName(for step: GuideStep) -> String {
        lang.currentLanguage == .ja ? step.imageJa : step.imageEn
    }

    private var isLastStep: Bool { currentStep == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                Spacer()
                if hasOpenedSettings {
                    Text("\(currentStep + 1) / \(steps.count)")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .medium))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .hidden()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.md)

            if !hasOpenedSettings {
                // 初期画面：設定を開くよう促す
                Spacer()

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accentGradient)

                Text(lang.l("focus_modal.title"))
                    .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppTheme.Spacing.md)

                Text(lang.l("focus_modal.message"))
                    .font(.system(size: AppTheme.FontSize.md))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.xs)

                Spacer()

                VStack(spacing: AppTheme.Spacing.sm) {
                    Button {
                        openFocusSettings()
                        withAnimation { hasOpenedSettings = true }
                    } label: {
                        Text(lang.l("focus_modal.open_settings"))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                    .fill(AppTheme.accentGradient)
                            )
                    }

                    Button { dismiss() } label: {
                        Text(lang.l("focus_modal.later"))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
            } else {
                // ガイド画面：設定を開いた後にステップを見ながら操作
                Text(lang.l(steps[currentStep].titleKey))
                    .font(.system(size: AppTheme.FontSize.lg, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppTheme.Spacing.md)
                    .padding(.horizontal, AppTheme.Spacing.md)

                Text(lang.l(steps[currentStep].descKey))
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.xs)

                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Image(imageName(for: steps[index]))
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md))
                            .shadow(color: .black.opacity(0.4), radius: 8)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? AppTheme.Colors.accent : AppTheme.Colors.surfaceVariant)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, AppTheme.Spacing.sm)

                // Buttons
                VStack(spacing: AppTheme.Spacing.sm) {
                    if isLastStep {
                        Button {
                            Self.markAsConfigured(uid: uid)
                            dismiss()
                        } label: {
                            Text(lang.l("focus_guide.done"))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                        .fill(AppTheme.accentGradient)
                                )
                        }
                    } else {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            Text(lang.l("focus_guide.next"))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                                        .fill(AppTheme.accentGradient)
                                )
                        }
                    }

                    Button { dismiss() } label: {
                        Text(lang.l("focus_modal.later"))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private func openFocusSettings() {
        if let url = URL(string: "App-prefs:") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Display Logic

    static func shouldShow(uid: String) -> Bool {
        if UserDefaults.standard.bool(forKey: configuredKeyPrefix + uid) {
            return false
        }
        let countKey = launchCountKeyPrefix + uid
        let count = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(count, forKey: countKey)
        return count % 5 == 1
    }

    static func markAsConfigured(uid: String) {
        UserDefaults.standard.set(true, forKey: configuredKeyPrefix + uid)
    }
}

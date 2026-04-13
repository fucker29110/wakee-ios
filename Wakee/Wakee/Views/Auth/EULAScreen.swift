import SwiftUI

struct EULAScreen: View {
    @AppStorage("hasAgreedToEULA") private var hasAgreedToEULA = false
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(lang.l("eula.title"))
                .font(.system(size: AppTheme.FontSize.xxl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)

            VStack(spacing: AppTheme.Spacing.md) {
                Text(lang.l("eula.description"))
                    .font(.system(size: AppTheme.FontSize.md))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button {
                    if let url = URL(string: "https://tokyoforge.co/wakee/terms") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(lang.l("eula.read_terms"))
                        .font(.system(size: AppTheme.FontSize.sm, weight: .medium))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()

            Button {
                hasAgreedToEULA = true
            } label: {
                Text(lang.l("eula.agree"))
                    .font(.system(size: AppTheme.FontSize.md, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .fill(AppTheme.accentGradient)
                    )
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }
}

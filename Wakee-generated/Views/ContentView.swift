import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isLoading {
                ZStack {
                    AppTheme.Colors.background.ignoresSafeArea()
                    VStack(spacing: AppTheme.Spacing.md) {
                        Text("Wakee")
                            .font(.system(size: AppTheme.FontSize.xxl, weight: .extrabold))
                            .foregroundStyle(AppTheme.accentGradient)
                        ProgressView()
                            .tint(AppTheme.Colors.accent)
                    }
                }
            } else if authVM.user != nil {
                MainTabView()
                    .environment(authVM)
            } else {
                LoginScreen()
                    .environment(authVM)
            }
        }
        .preferredColorScheme(.dark)
    }
}

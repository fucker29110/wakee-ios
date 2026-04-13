import SwiftUI
import FirebaseMessaging

struct ContentView: View {
    @State private var authVM = AuthViewModel()
    @State private var langManager = LanguageManager.shared
    @Bindable private var alarmManager = AlarmManager.shared
    @AppStorage("hasAgreedToEULA") private var hasAgreedToEULA = false

    var body: some View {
        Group {
            if authVM.isLoading {
                ZStack {
                    AppTheme.Colors.background.ignoresSafeArea()
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        Text("Wakee")
                            .font(.system(size: AppTheme.FontSize.xxl, weight: .heavy))
                            .foregroundStyle(AppTheme.accentGradient)
                        ProgressView()
                            .tint(AppTheme.Colors.accent)
                    }
                }
            } else if authVM.user != nil, authVM.needsEmailVerification {
                EmailVerificationScreen()
                    .environment(authVM)
                    .environment(langManager)
            } else if authVM.user != nil, !hasAgreedToEULA {
                EULAScreen()
            } else if authVM.user != nil, authVM.needsOnboarding {
                OnboardingScreen()
                    .environment(authVM)
            } else if let user = authVM.user {
                MainTabView()
                    .environment(authVM)
                    .task {
                        if let token = try? await Messaging.messaging().token() {
                            try? await AuthService.shared.saveFcmToken(uid: user.uid, token: token)
                        }
                        // アラーム監視開始
                        AlarmManager.shared.startMonitoring(uid: user.uid)
                    }
                    .onDisappear {
                        AlarmManager.shared.stopMonitoring()
                    }
                    .fullScreenCover(isPresented: $alarmManager.isRinging) {
                        RingingScreen(
                            eventId: alarmManager.currentEventId,
                            senderName: alarmManager.currentSenderName,
                            senderUid: alarmManager.currentSenderUid,
                            time: alarmManager.currentTime,
                            message: alarmManager.currentMessage,
                            snoozeMin: alarmManager.currentSnoozeMin,
                            receiverUid: alarmManager.currentReceiverUid,
                            snoozeCount: alarmManager.currentSnoozeCount,
                            audioURL: alarmManager.currentAudioURL,
                            isPrivate: alarmManager.currentIsPrivate
                        )
                    }
            } else {
                LoginScreen()
                    .environment(authVM)
            }
        }
        .environment(langManager)
        .preferredColorScheme(.dark)
    }
}

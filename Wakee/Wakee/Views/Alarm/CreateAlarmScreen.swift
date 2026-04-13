import SwiftUI
import AVFoundation

struct CreateAlarmScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    @Environment(LanguageManager.self) private var lang
    @State private var alarmVM = AlarmViewModel()
    @State private var recordingService = AudioRecordingService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showErrorAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Friend selector
                sectionCard(icon: "person.2", title: lang.l("alarm.recipient")) {
                    if friendsVM.friends.isEmpty {
                        Text(lang.l("alarm.no_friends"))
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .padding(AppTheme.Spacing.md)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(friendsVM.friends) { friend in
                                friendRow(friend)
                            }
                        }
                    }
                }

                // Time picker
                sectionCard(icon: "clock", title: lang.l("alarm.time")) {
                    TimePickerView(time: Binding(
                        get: { alarmVM.time },
                        set: { alarmVM.time = $0 }
                    ))
                }

                // Message
                sectionCard(icon: "bubble.left", title: lang.l("alarm.message_optional")) {
                    TextField(lang.l("alarm.message_placeholder"), text: Binding(
                        get: { alarmVM.message },
                        set: { alarmVM.message = String($0.prefix(alarmVM.maxMessageLength)) }
                    ))
                    .textFieldStyle(DarkTextFieldStyle())
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)

                    HStack {
                        Spacer()
                        Text("\(alarmVM.message.count)/\(alarmVM.maxMessageLength)")
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.sm)
                }

                // Recording section
                sectionCard(icon: "mic", title: lang.l("alarm.voice_optional")) {
                    recordingSection
                }

                // Private mode
                sectionCard(icon: alarmVM.isPrivate ? "lock.fill" : "lock.open", title: lang.l("alarm.private")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.l("alarm.hidden_from_timeline"))
                                .font(.system(size: AppTheme.FontSize.sm))
                                .foregroundColor(AppTheme.Colors.primary)
                            Text(lang.l("alarm.private_desc"))
                                .font(.system(size: AppTheme.FontSize.xs))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { alarmVM.isPrivate },
                            set: { alarmVM.isPrivate = $0 }
                        ))
                        .tint(AppTheme.Colors.accent)
                        .labelsHidden()
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                }

                // Send button
                GradientButton(
                    title: alarmVM.selectedFriends.isEmpty
                        ? lang.l("alarm.send")
                        : lang.l("alarm.send_to", args: alarmVM.selectedFriends.count),
                    icon: "alarm.fill",
                    isLoading: alarmVM.isSending,
                    disabled: !alarmVM.canSend || recordingService.isRecording || recordingService.isMerging
                ) {
                    sendAlarm()
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, 40)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("alarm.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(lang.l("alarm.send_complete"), isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .alert(lang.l("common.error"), isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(recordingService.errorMessage ?? "")
        }
        .onChange(of: recordingService.errorMessage) { _, newValue in
            if newValue != nil {
                showErrorAlert = true
            }
        }
    }

    private func sectionCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.accent)
                Text(title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.primary)

                if icon == "person.2" && !alarmVM.selectedFriends.isEmpty {
                    Text(lang.l("alarm.selected", args: alarmVM.selectedFriends.count))
                        .font(.system(size: AppTheme.FontSize.xs, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.accent.opacity(0.2))
                                .overlay(Capsule().stroke(AppTheme.Colors.accent, lineWidth: 1))
                        )
                }

                Spacer()
            }
            .font(.system(size: AppTheme.FontSize.sm))
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.sm)

            content()
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                .stroke(Color(hex: "#333333"), lineWidth: 1)
        )
    }

    private func friendRow(_ friend: AppUser) -> some View {
        Button(action: { alarmVM.toggleFriend(friend.uid) }) {
            HStack(spacing: AppTheme.Spacing.sm) {
                AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 36)
                Text(friend.displayName)
                    .foregroundColor(AppTheme.Colors.primary)
                Spacer()
                Image(systemName: alarmVM.selectedFriends.contains(friend.uid) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(alarmVM.selectedFriends.contains(friend.uid) ? AppTheme.Colors.accent : AppTheme.Colors.secondary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 10)
        }
    }

    // MARK: - 録音セクション

    @ViewBuilder
    private var recordingSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if recordingService.isMerging {
                // 結合処理中
                HStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                    Text(lang.l("alarm.processing_audio"))
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .padding(AppTheme.Spacing.md)
            } else if recordingService.isRecording {
                // 録音中
                VStack(spacing: AppTheme.Spacing.sm) {
                    Button(action: {
                        Task { await recordingService.stopRecording() }
                    }) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)

                            Text(lang.l("alarm.recording", args: formatDuration(recordingService.recordingDuration)))
                                .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }

                    // 進捗バー
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.Colors.accent)
                                .frame(width: geo.size.width * min(recordingService.recordingDuration / 15.0, 1.0), height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                .padding(AppTheme.Spacing.md)
            } else if recordingService.recordedFileURL != nil {
                // 録音済み
                HStack(spacing: AppTheme.Spacing.md) {
                    Button(action: {
                        if recordingService.isPlaying {
                            recordingService.stopPreview()
                        } else {
                            recordingService.playPreview()
                        }
                    }) {
                        Label(
                            recordingService.isPlaying ? lang.l("common.stop") : lang.l("common.play"),
                            systemImage: recordingService.isPlaying ? "stop.fill" : "play.fill"
                        )
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                .fill(AppTheme.Colors.accent.opacity(0.15))
                        )
                    }

                    Button(action: {
                        recordingService.deleteRecording()
                    }) {
                        Label(lang.l("alarm.retake"), systemImage: "arrow.counterclockwise")
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button(action: {
                        recordingService.deleteRecording()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }

                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
            } else {
                // 録音前
                Button(action: {
                    recordingService.startRecording()
                }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                        Text(lang.l("alarm.tap_to_record"))
                            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.accent)
                    )
                }
                .padding(AppTheme.Spacing.md)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "0:%02d", seconds)
    }

    // MARK: - 送信

    private func sendAlarm() {
        guard let user = authVM.user else { return }
        let count = alarmVM.selectedFriends.count
        let time = alarmVM.time
        Task {
            let success = await alarmVM.sendAlarm(
                user: user,
                friends: friendsVM.friends,
                recordingService: recordingService
            )
            if success {
                recordingService.deleteRecording()
                alertMessage = lang.l("alarm.sent_message", args: count, time)
                showAlert = true
            }
        }
    }
}

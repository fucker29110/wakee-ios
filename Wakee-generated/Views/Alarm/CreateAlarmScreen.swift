import SwiftUI

struct CreateAlarmScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var alarmVM = AlarmViewModel()
    @State private var friendsVM = FriendsViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                // Friend selector
                sectionCard(icon: "person.2", title: "宛先") {
                    if friendsVM.friends.isEmpty {
                        Text("フレンドがいません。フレンドタブから友達を追加してください。")
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
                sectionCard(icon: "clock", title: "時刻") {
                    TimePickerView(time: Binding(
                        get: { alarmVM.time },
                        set: { alarmVM.time = $0 }
                    ))
                }

                // Message
                sectionCard(icon: "bubble.left", title: "メッセージ（任意）") {
                    TextField("おはよう！起きて！", text: Binding(
                        get: { alarmVM.message },
                        set: { alarmVM.message = $0 }
                    ))
                    .textFieldStyle(DarkTextFieldStyle())
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)

                    HStack {
                        Spacer()
                        Text("\(alarmVM.message.count)/200")
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.sm)
                }

                // Voice message
                sectionCard(icon: "mic", title: "ボイスメッセージ（任意）") {
                    HStack {
                        if alarmVM.recordingData != nil {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                Text("録音済み")
                                    .foregroundColor(AppTheme.Colors.success)
                                Spacer()
                                Button(action: { alarmVM.recordingData = nil }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(AppTheme.Colors.danger)
                                }
                            }
                        } else {
                            Button(action: { alarmVM.showRecordingModal = true }) {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                    Text("録音する")
                                        .foregroundColor(AppTheme.Colors.accent)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                                        .fill(AppTheme.Colors.surfaceVariant)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                }

                // Send button
                GradientButton(
                    title: alarmVM.selectedFriends.isEmpty
                        ? "アラームを送る"
                        : "\(alarmVM.selectedFriends.count)人にアラームを送る",
                    icon: "alarm.fill",
                    isLoading: alarmVM.isSending,
                    disabled: !alarmVM.canSend
                ) {
                    sendAlarm()
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, 40)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("アラーム送信")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { alarmVM.showRecordingModal },
            set: { alarmVM.showRecordingModal = $0 }
        )) {
            RecordingModal(onRecorded: { data in
                alarmVM.recordingData = data
            })
        }
        .alert("送信完了", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            friendsVM.subscribe(uid: uid)
        }
        .onDisappear { friendsVM.unsubscribe() }
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
                    Text("\(alarmVM.selectedFriends.count)人選択中")
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

    private func sendAlarm() {
        guard let user = authVM.user else { return }
        Task {
            let success = await alarmVM.sendAlarm(user: user, friends: friendsVM.friends)
            if success {
                alertMessage = "\(alarmVM.selectedFriends.count)人に \(alarmVM.time) のアラームを送信しました"
                showAlert = true
            }
        }
    }
}

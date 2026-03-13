# 録音（ボイスメッセージ）機能バックアップ

> **削除日**: 2026-03-04
> **理由**: ロック画面通知で音が出ないバグの切り分けのため一時削除
> **復元時**: このファイルのコードを各ファイルに戻す

---

## 1. RecordingModal.swift（ファイルごと削除）

パス: `Wakee/Wakee/Views/Alarm/RecordingModal.swift`

```swift
import SwiftUI
import AVFoundation

struct RecordingModal: View {
    let onRecorded: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var recordedURL: URL?
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    private let maxDuration: TimeInterval = 10

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    Spacer()

                    // Timer display
                    Text(String(format: "%01d:%02d", Int(recordingTime) / 60, Int(recordingTime) % 60))
                        .font(.system(size: AppTheme.FontSize.xxl, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.primary)

                    Text("最大10秒")
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.secondary)

                    // Record button
                    if recordedURL != nil {
                        VStack(spacing: AppTheme.Spacing.md) {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.success)
                                Text("録音完了")
                                    .foregroundColor(AppTheme.Colors.success)
                                    .fontWeight(.semibold)
                            }

                            // Preview play button
                            Button(action: togglePreview) {
                                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.Colors.accent)
                            }

                            HStack(spacing: AppTheme.Spacing.lg) {
                                Button(action: retake) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("再録音")
                                    }
                                    .foregroundColor(AppTheme.Colors.accent)
                                }

                                GradientButton(title: "使用する") {
                                    confirmRecording()
                                }
                                .frame(width: 140)
                            }
                        }
                    } else {
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? AppTheme.Colors.danger : AppTheme.Colors.accent)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: (isRecording ? AppTheme.Colors.danger : AppTheme.Colors.accent).opacity(0.4), radius: 12)

                                if isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.white)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }

                        Text(isRecording ? "タップして停止" : "タップして録音")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }

                    // Progress bar
                    if isRecording {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.Colors.surfaceVariant)
                                    .frame(height: 4)
                                Capsule()
                                    .fill(AppTheme.Colors.accent)
                                    .frame(width: geo.size.width * (recordingTime / maxDuration), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        stopPreview()
                        stopRecording()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .onDisappear {
            stopPreview()
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("alarm_recording_\(Int(Date().timeIntervalSince1970)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record(forDuration: maxDuration)
            recordedURL = nil
            recordingTime = 0
            isRecording = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingTime = recorder?.currentTime ?? 0
                if recordingTime >= maxDuration {
                    stopRecording()
                }
            }
        } catch {
            print("Recording error: \(error)")
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        guard isRecording else { return }
        isRecording = false
        recorder?.stop()
        recordedURL = recorder?.url
    }

    private func retake() {
        stopPreview()
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        recordingTime = 0
    }

    private func confirmRecording() {
        stopPreview()
        guard let url = recordedURL,
              let data = try? Data(contentsOf: url) else { return }
        onRecorded(data)
        dismiss()
    }

    // MARK: - Preview Playback

    private func togglePreview() {
        if isPlaying {
            stopPreview()
        } else {
            playPreview()
        }
    }

    private func playPreview() {
        guard let url = recordedURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if player?.isPlaying != true {
                    isPlaying = false
                    timer?.invalidate()
                    timer = nil
                }
            }
        } catch {
            print("Playback error: \(error)")
        }
    }

    private func stopPreview() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
}
```

---

## 2. NotificationService.swift — 削除部分

### 削除: `import AVFoundation`
### 削除: `downloadAndSetSound()`, `convertToWAV()`, `copyDefaultSoundToSharedContainer()`, `setDefaultAlarmSound()`

```swift
// audioURL 分岐部分（didReceive 内）:
let audioURL = userInfo["audioURL"] as? String
if let audioURL, !audioURL.isEmpty {
    downloadAndSetSound(urlString: audioURL, content: content) { updatedContent in
        contentHandler(updatedContent)
    }
} else {
    setDefaultAlarmSound(content: content)
    contentHandler(content)
}

// setDefaultAlarmSound:
private func setDefaultAlarmSound(content: UNMutableNotificationContent) {
    if copyDefaultSoundToSharedContainer() {
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_notif.wav"))
    } else {
        content.sound = .default
    }
}

// downloadAndSetSound:
private func downloadAndSetSound(
    urlString: String,
    content: UNMutableNotificationContent,
    completion: @escaping (UNMutableNotificationContent) -> Void
) {
    guard let url = URL(string: urlString) else {
        setDefaultAlarmSound(content: content)
        completion(content)
        return
    }
    let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
        guard let tempURL, error == nil else {
            self.setDefaultAlarmSound(content: content)
            completion(content)
            return
        }
        if let wavURL = self.convertToWAV(sourceURL: tempURL) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(wavURL.lastPathComponent))
        } else {
            self.setDefaultAlarmSound(content: content)
        }
        completion(content)
    }
    task.resume()
}

// convertToWAV: (全体は上記ファイル参照)

// copyDefaultSoundToSharedContainer:
@discardableResult
private func copyDefaultSoundToSharedContainer() -> Bool {
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroupID
    ) else { return false }
    let soundsDir = containerURL.appendingPathComponent("Library/Sounds", isDirectory: true)
    try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
    let destURL = soundsDir.appendingPathComponent("alarm_notif.wav")
    if FileManager.default.fileExists(atPath: destURL.path) { return true }
    guard let bundleURL = Bundle(for: NotificationService.self)
        .url(forResource: "alarm_notif", withExtension: "wav") else { return false }
    do {
        try FileManager.default.copyItem(at: bundleURL, to: destURL)
        return true
    } catch {
        print("[NotificationService] Failed to copy default sound: \(error)")
        return false
    }
}
```

---

## 3. AlarmSoundService.swift — remote audio 部分

```swift
// play() の remote audio ブランチ:
if let urlString = audioURL, let url = URL(string: urlString) {
    Task {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                self.startPlayback(data: data)
            }
        } catch {
            print("[AlarmSound] Remote audio download failed: \(error)")
            await MainActor.run { self.playDefaultSound() }
        }
    }
} else {
    playDefaultSound()
}
```

---

## 4. AlarmViewModel.swift — 録音関連

```swift
// プロパティ:
var recordingData: Data?
var showRecordingModal = false

// sendAlarm() 内の audioURL アップロード:
var audioURL: String?
if let data = recordingData {
    audioURL = try await StorageService.shared.uploadAlarmAudio(
        senderUid: user.uid,
        audioData: data
    )
}

// sendAlarm() での audioURL パラメータ渡し:
audioURL: audioURL

// sendAlarm() 末尾のリセット:
recordingData = nil
```

---

## 5. StorageService.swift — uploadAlarmAudio

```swift
func uploadAlarmAudio(senderUid: String, audioData: Data) async throws -> String {
    let filename = "\(senderUid)_\(Int(Date().timeIntervalSince1970)).m4a"
    let ref = storage.reference().child("alarm_audio/\(filename)")
    let metadata = StorageMetadata()
    metadata.contentType = "audio/mp4"
    _ = try await ref.putDataAsync(audioData, metadata: metadata)
    let url = try await ref.downloadURL()
    return url.absoluteString
}
```

---

## 6. AlarmService.swift — audioURL パラメータ

```swift
// sendAlarm() の audioURL パラメータ:
audioURL: String? = nil

// data dict 内:
"audioURL": audioURL as Any,
```

---

## 7. CreateAlarmScreen.swift — 録音UI

```swift
// ボイスメッセージ sectionCard:
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

// RecordingModal sheet:
.sheet(isPresented: Binding(
    get: { alarmVM.showRecordingModal },
    set: { alarmVM.showRecordingModal = $0 }
)) {
    RecordingModal(onRecorded: { data in
        alarmVM.recordingData = data
    })
}
```

---

## 8. AlarmManager.swift — audioURL 関連

```swift
// プロパティ:
var currentAudioURL: String?

// triggerFromNotification 内:
let audioURL = (userInfo["audioURL"] as? String)?.nilIfEmpty

// showRingingScreen パラメータ:
audioURL: audioURL

// showRingingScreen メソッドシグネチャ:
private func showRingingScreen(..., audioURL: String?)

// showRingingScreen 内:
currentAudioURL = audioURL

// checkForDueAlarms 内:
audioURL: event.audioURL

// performSnooze 内:
audioURL: String?  // パラメータ
// InboxEvent 構築時:
audioURL: audioURL
```

---

## 9. RingingScreen.swift — audioURL

```swift
// プロパティ:
var audioURL: String?

// onAppear 内:
AlarmSoundService.shared.play(audioURL: audioURL)

// handleSnooze 内:
audioURL: audioURL
```

---

## 10. WakeeApp.swift — audioURL 関連（3箇所）

```swift
// didReceiveRemoteNotification 内:
let audioURL = (userInfo["audioURL"] as? String)?.nilIfEmpty
AlarmSoundService.shared.play(audioURL: audioURL)

// handleAlarmAction 内:
let audioURL = userInfo["audioURL"] as? String
// SNOOZE_ALARM 内:
audioURL: audioURL

// handleExtensionAlarm 内:
let audioURL = (userInfo["audioURL"] as? String)?.nilIfEmpty
AlarmSoundService.shared.play(audioURL: audioURL)
```

---

## 11. ContentView.swift — audioURL 渡し

```swift
// RingingScreen 生成時:
audioURL: alarmManager.currentAudioURL
```

---

## 12. InboxEvent.swift — audioURL フィールド

**注意**: `audioURL` フィールドは既存 Firestore データとの互換性のため**削除しない**。

```swift
var audioURL: String?
// CodingKeys 内にも audioURL あり
```

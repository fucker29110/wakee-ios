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
                        stopRecording()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .onDisappear { stopRecording() }
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
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        recordingTime = 0
    }

    private func confirmRecording() {
        guard let url = recordedURL,
              let data = try? Data(contentsOf: url) else { return }
        onRecorded(data)
        dismiss()
    }
}

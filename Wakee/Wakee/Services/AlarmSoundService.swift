import Foundation
import AVFoundation
import AudioToolbox

final class AlarmSoundService {
    static let shared = AlarmSoundService()
    private var player: AVAudioPlayer?
    private var watchdogTimer: Timer?
    private var vibrationTimer: Timer?
    private var vibrationStopTimer: Timer?
    private var downloadTask: Task<Void, Never>?
    private let vibrationDuration: TimeInterval = 30.0
    private(set) var isPlaying = false
    private init() {}

    func play() {
        play(audioURL: nil)
    }

    /// audioURLがある場合は録音音声をダウンロードしてループ再生、なければデフォルト音
    func play(audioURL: String?) {
        guard !isPlaying else { return }
        stop()

        // バイブレーションを即座に開始（ダウンロード完了を待たない）
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        startVibration()
        isPlaying = true

        if let urlString = audioURL, let url = URL(string: urlString) {
            // ローカルキャッシュがあれば即座に再生、なければダウンロード
            if let cachedData = AlarmAudioCache.shared.load(for: urlString) {
                startPlayback(data: cachedData)
            } else {
                downloadTask = Task { [weak self] in
                    do {
                        let (localURL, _) = try await URLSession.shared.download(from: url)
                        guard !Task.isCancelled else { return }
                        let data = try Data(contentsOf: localURL)
                        await MainActor.run { [weak self] in
                            guard let self, self.isPlaying else { return }
                            self.startPlayback(data: data)
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        print("[AlarmSound] Audio download failed: \(error), falling back to default")
                        await MainActor.run { [weak self] in
                            guard let self, self.isPlaying else { return }
                            self.playDefaultSound()
                        }
                    }
                }
            }
        } else {
            playDefaultSound()
        }
    }

    private func playDefaultSound() {
        guard let url = Bundle.main.url(forResource: "alarm_notif", withExtension: "wav") else {
            print("[AlarmSound] Default sound file not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            startPlayback(data: data)
        } catch {
            print("[AlarmSound] Failed to load default sound: \(error)")
        }
    }

    private func startPlayback(data: Data) {
        // 音声再生直前にオーディオセッションを設定（通知サウンドとの競合を避ける）
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AlarmSound] Audio session setup failed: \(error)")
        }

        do {
            player = try AVAudioPlayer(data: data)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.play()
            startWatchdog()
        } catch {
            print("[AlarmSound] Playback failed: \(error)")
        }
    }

    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let player = self?.player else { return }
            player.volume = 1.0
            if !player.isPlaying {
                player.currentTime = 0
                player.play()
            }
        }
    }

    private func startVibration() {
        vibrationTimer?.invalidate()
        vibrationStopTimer?.invalidate()
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        // 30秒後にバイブのみ自動停止
        vibrationStopTimer = Timer.scheduledTimer(withTimeInterval: vibrationDuration, repeats: false) { [weak self] _ in
            self?.vibrationTimer?.invalidate()
            self?.vibrationTimer = nil
            self?.vibrationStopTimer = nil
        }
    }

    func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        vibrationStopTimer?.invalidate()
        vibrationStopTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

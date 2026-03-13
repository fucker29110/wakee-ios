import Foundation
import AVFoundation
import AudioToolbox

final class AlarmSoundService {
    static let shared = AlarmSoundService()
    private var player: AVAudioPlayer?
    private var watchdogTimer: Timer?
    private var vibrationTimer: Timer?
    private init() {}

    func play(audioURL: String? = nil) {
        stop()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AlarmSound] Audio session setup failed: \(error)")
        }

        if let urlString = audioURL, let url = URL(string: urlString) {
            // Remote audio
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
    }

    private func playDefaultSound() {
        guard let url = Bundle.main.url(forResource: "alarm_notif", withExtension: "wav") else {
            print("[AlarmSound] Default sound file not found")
            startVibration()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            startPlayback(data: data)
        } catch {
            print("[AlarmSound] Failed to load default sound: \(error)")
            startVibration()
        }
    }

    private func startPlayback(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.play()
            startWatchdog()
            startVibration()
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
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func stop() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

import AVFoundation
import FirebaseStorage

@Observable
final class AudioRecordingService: NSObject, AVAudioPlayerDelegate {

    // MARK: - State
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var recordedFileURL: URL? // 結合済み最終ファイルのURL
    var errorMessage: String?
    var isMerging = false

    // MARK: - Private
    private var audioRecorder: AVAudioRecorder?
    private var rawRecordingURL: URL?
    private var durationTimer: Timer?
    private let maxDuration: TimeInterval = 15.0
    private let targetDuration: TimeInterval = 30.0

    // MARK: - Recording

    /// 録音開始。マイク権限がない場合はerrorMessageをセット
    func startRecording() {
        errorMessage = nil

        // マイク権限チェック
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = LanguageManager.shared.l("service.audio_session_failed")
            return
        }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.errorMessage = LanguageManager.shared.l("service.mic_permission_denied")
                }
            }
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        rawRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, self.isRecording else { return }
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
                if self.recordingDuration >= self.maxDuration {
                    Task { await self.stopRecording() }
                }
            }
        } catch {
            errorMessage = LanguageManager.shared.l("service.recording_start_failed", args: error.localizedDescription)
        }
    }

    /// 録音停止 → 30秒結合処理を実行
    @MainActor
    func stopRecording() async {
        guard isRecording else { return }
        audioRecorder?.stop()
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil

        // 録音が短すぎる場合
        if recordingDuration < 0.5 {
            deleteRecording()
            return
        }

        isMerging = true
        await mergeToThirtySeconds()
        if let url = recordedFileURL {
            normalizeAudio(at: url)
        }
        isMerging = false
    }

    /// 録音を破棄してリセット
    func deleteRecording() {
        if let url = rawRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = recordedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioRecorder = nil
        rawRecordingURL = nil
        recordedFileURL = nil
        recordingDuration = 0
        isRecording = false
        isMerging = false
        errorMessage = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Merge（30秒結合）

    /// 録音ファイルを繰り返し結合して約30秒のファイルを生成
    private func mergeToThirtySeconds() async {
        guard let rawURL = rawRecordingURL else { return }

        let asset = AVAsset(url: rawURL)

        do {
            let duration = try await asset.load(.duration)
            let singleDuration = CMTimeGetSeconds(duration)
            guard singleDuration > 0 else {
                errorMessage = LanguageManager.shared.l("service.recording_file_empty")
                return
            }

            let repeatCount = max(1, Int(targetDuration / singleDuration))

            let composition = AVMutableComposition()
            guard let track = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                errorMessage = LanguageManager.shared.l("service.audio_processing_failed")
                return
            }

            let assetTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let sourceTrack = assetTracks.first else {
                errorMessage = LanguageManager.shared.l("service.audio_track_not_found")
                return
            }

            var currentTime = CMTime.zero
            for _ in 0..<repeatCount {
                // 30秒を超えないようチェック
                let remaining = CMTimeMakeWithSeconds(targetDuration, preferredTimescale: 600) - currentTime
                if remaining <= .zero { break }
                let insertDuration = min(duration, remaining)
                let insertRange = CMTimeRange(start: .zero, duration: insertDuration)
                try track.insertTimeRange(insertRange, of: sourceTrack, at: currentTime)
                currentTime = currentTime + insertDuration
            }

            // エクスポート
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_merged.m4a")

            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
            ) else {
                errorMessage = LanguageManager.shared.l("service.audio_processing_failed")
                return
            }
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a

            await exportSession.export()

            if exportSession.status == .completed {
                await MainActor.run {
                    self.recordedFileURL = outputURL
                }
            } else {
                await MainActor.run {
                    self.errorMessage = LanguageManager.shared.l("service.audio_export_failed", args: exportSession.error?.localizedDescription ?? "")
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = LanguageManager.shared.l("service.audio_export_failed", args: error.localizedDescription)
            }
        }
    }

    // MARK: - Normalize（音量正規化）

    /// ピーク値を基準に音量を最大化し、M4A(AAC)形式で上書き保存する
    private func normalizeAudio(at url: URL) {
        do {
            let inputFile = try AVAudioFile(forReading: url)
            let format = inputFile.processingFormat
            let frameCount = AVAudioFrameCount(inputFile.length)
            guard frameCount > 0 else { return }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("[AudioRecording] Failed to create buffer for normalization")
                return
            }
            try inputFile.read(into: buffer)

            // 全サンプルからピーク値を取得
            let channelCount = Int(format.channelCount)
            var peak: Float = 0.0
            for ch in 0..<channelCount {
                guard let channelData = buffer.floatChannelData?[ch] else { continue }
                for i in 0..<Int(buffer.frameLength) {
                    let sample = Swift.abs(channelData[i])
                    if sample > peak { peak = sample }
                }
            }

            // ピークが0または既にほぼ最大音量なら処理不要
            let gain = 1.0 / peak
            guard peak > 0, gain > 1.01 else { return }

            // ゲインを全サンプルに適用
            for ch in 0..<channelCount {
                guard let channelData = buffer.floatChannelData?[ch] else { continue }
                for i in 0..<Int(buffer.frameLength) {
                    channelData[i] *= gain
                }
            }

            // M4A(AAC)形式で一時ファイルに書き出し → 元ファイルを置き換え
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_normalized.m4a")
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let outputFile = try AVAudioFile(
                forWriting: tempURL,
                settings: outputSettings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            try outputFile.write(from: buffer)

            // 元ファイルを正規化済みファイルで置き換え
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: tempURL, to: url)

            print("[AudioRecording] Normalized: peak=\(peak), gain=\(String(format: "%.2f", gain))x")
        } catch {
            print("[AudioRecording] Normalization failed: \(error.localizedDescription)")
            // 正規化失敗しても元ファイルはそのまま使う
        }
    }

    // MARK: - Upload

    /// Firebase Storage にアップロードしてダウンロードURLを返す
    /// アップロードと同時にローカルキャッシュにも保存する
    func uploadRecording(eventId: String) async throws -> String {
        guard let fileURL = recordedFileURL else {
            throw AudioRecordingError.noRecording
        }

        let data = try Data(contentsOf: fileURL)

        // ローカルキャッシュに保存（受信時にダウンロード不要で即座再生するため）
        AlarmAudioCache.shared.save(data: data, for: eventId)

        let ref = Storage.storage().reference().child("alarm_audio/\(eventId).m4a")
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mp4"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Playback（プレビュー用）

    var isPlaying = false
    private var previewPlayer: AVAudioPlayer?

    func playPreview() {
        guard let url = recordedFileURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.numberOfLoops = 0
            previewPlayer?.delegate = self
            previewPlayer?.play()
            isPlaying = true
        } catch {
            errorMessage = LanguageManager.shared.l("service.playback_failed")
        }
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPlaying = false
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecordingService {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("[AudioRecordingService] 再生終了")
        isPlaying = false
    }
}

// MARK: - Error
enum AudioRecordingError: LocalizedError {
    case noRecording

    var errorDescription: String? {
        switch self {
        case .noRecording: return LanguageManager.shared.l("service.recording_file_not_found")
        }
    }
}

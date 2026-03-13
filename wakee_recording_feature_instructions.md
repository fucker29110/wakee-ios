# Wakee 録音機能 実装指示書
## Claude Code向け・バグゼロ実装ガイド

---

## 前提・重要ルール

- **既存コードを壊さない**。既存ファイルを編集する前に必ずファイル全体を読み込むこと
- **一度に大量の変更をしない**。1ステップずつ実装し、各ステップ後にビルドエラーがないか確認すること
- **新規ファイルは必ず既存の命名規則・フォルダ構成に合わせる**
- **TODO・仮実装を残さない**。全て動作する実装で完成させること
- **既存のFirebase設定・Bundle ID（com.wakee.app）・App Group設定を変更しない**

---

## 実装する機能の概要

アラーム送信時に音声を録音し、受信者のロック画面とRingingScreenで再生する機能。

### 動作仕様
| | 録音あり | 録音なし |
|---|---|---|
| ロック画面 | 録音音声（〜30秒、1回再生） | 既存のデフォルトアラーム音 |
| RingingScreen | 録音音声をループ再生 | 既存のデフォルトアラーム音ループ |

### データフロー
```
送信者が録音（最大15秒）
  → iOS端末上でAVFoundationを使い30秒になるよう繰り返し結合
  → Firebase Storageにアップロード（recordings/{eventId}.m4a）
  → InboxEventのFirestoreドキュメントにaudioURLを保存
  → FCM通知送信（既存フロー）
  → 受信側NotificationServiceExtensionがaudioURLをダウンロード
  → 通知サウンドとして添付（ロック画面で1回再生）
  → RingingScreen起動時にaudioURLをAVAudioPlayerでループ再生
```

---

## ステップ1：データモデルの更新

### 対象ファイル
既存の `InboxEvent` モデルファイルを探して開くこと。

### 変更内容
`InboxEvent` 構造体に以下のプロパティを追加する：

```swift
var audioURL: String? // 録音ファイルのURL。nilの場合はデフォルトアラーム音を使用
```

- `Codable` / `Identifiable` など既存のプロトコル準拠を壊さないこと
- Firestoreのエンコード・デコードが既存の実装方法に合わせて動作すること
- `audioURL` が存在しない古いドキュメントも正常にデコードできること（`nil` になればOK）

---

## ステップ2：録音サービスの新規作成

### ファイル名
`AudioRecordingService.swift`（既存のServiceファイルと同じディレクトリに作成）

### 実装内容

```swift
import AVFoundation
import FirebaseStorage

@Observable
final class AudioRecordingService: NSObject {

    // MARK: - State
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var recordedFileURL: URL? // 結合済み最終ファイルのURL
    var errorMessage: String?

    // MARK: - Private
    private var audioRecorder: AVAudioRecorder?
    private var rawRecordingURL: URL? // 録音した生ファイル
    private var durationTimer: Timer?
    private let maxDuration: TimeInterval = 15.0
    private let targetDuration: TimeInterval = 30.0

    // MARK: - Recording
    
    /// 録音開始。マイク権限がない場合はerrorMessageをセット
    func startRecording() {
        // 1. AVAudioSession を録音用に設定
        // 2. 一時ディレクトリにrawRecordingURLを設定（UUID().uuidString + ".m4a"）
        // 3. AVAudioRecorderを初期化・record()
        // 4. isRecording = true
        // 5. タイマーで recordingDuration を毎秒更新、15秒で自動停止
    }

    /// 録音停止 → 30秒結合処理を実行
    func stopRecording() async {
        // 1. audioRecorder?.stop()
        // 2. isRecording = false、タイマー停止
        // 3. mergeToThirtySeconds() を呼び出す
    }

    /// 録音を破棄してリセット
    func deleteRecording() {
        // recordedFileURL, rawRecordingURL を削除
        // 全プロパティをリセット
    }

    // MARK: - Merge（30秒結合）

    /// 録音ファイルを繰り返し結合して約30秒のファイルを生成
    /// 例：5秒録音 → 6回繰り返し = 30秒
    private func mergeToThirtySeconds() async {
        guard let rawURL = rawRecordingURL else { return }

        let asset = AVAsset(url: rawURL)
        
        // 1. asset の duration を取得
        // 2. 繰り返し回数を計算：Int(targetDuration / singleDuration) （切り捨て、最低1回）
        //    ただし合計が30秒を超えないようにすること
        // 3. AVMutableComposition を使って繰り返し結合
        // 4. 出力先URLを一時ディレクトリに設定（UUID + "_merged.m4a"）
        // 5. AVAssetExportSession で m4a としてエクスポート
        // 6. 成功したら recordedFileURL にセット
        // 7. 失敗したら errorMessage にセット
    }

    // MARK: - Upload

    /// Firebase Storage にアップロードしてダウンロードURLを返す
    func uploadRecording(eventId: String) async throws -> String {
        guard let fileURL = recordedFileURL else {
            throw AudioRecordingError.noRecording
        }
        // 1. Storage の recordings/{eventId}.m4a にアップロード
        // 2. ダウンロードURLを取得して返す
    }
}

// MARK: - Error
enum AudioRecordingError: LocalizedError {
    case noRecording
    case mergeFailed
    case uploadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noRecording: return "録音ファイルが見つかりません"
        case .mergeFailed: return "音声の処理に失敗しました"
        case .uploadFailed(let e): return "アップロード失敗: \(e.localizedDescription)"
        }
    }
}
```

### 注意事項
- AVAudioSession のカテゴリ設定は `.playAndRecord`、モードは `.default`
- 録音フォーマット：`[.formatID: kAudioFormatMPEG4AAC, .sampleRate: 44100.0, .numberOfChannels: 1, .encoderAudioQualityKey: AVAudioQuality.high.rawValue]`
- 一時ファイルは `FileManager.default.temporaryDirectory` に保存
- `deleteRecording()` 時に一時ファイルを `FileManager` で削除すること（ストレージリーク防止）
- MainActor への切り替えが必要な箇所は `@MainActor` を適切に使うこと

---

## ステップ3：送信画面への録音UIの追加

### 対象ファイル
既存のアラーム送信画面ファイルを探して開くこと（AlarmSendView, CreateAlarmView など）。

### 追加するUI

送信画面の「メッセージ入力欄」の下に録音セクションを追加する。

**録音前の状態：**
```
[🎙️ 長押しで録音]  ← 円形ボタン、アクセントカラー(#FF6B35)
```

**録音中の状態：**
```
[🔴 録音中... 0:08]  ← 赤い点滅アニメーション + 経過秒数
※ 指を離したら停止
```

**録音後の状態：**
```
[▶ 再生]  [🔄 撮り直し]  [🗑️ 削除]
```

### 実装ルール
- `AudioRecordingService` を `@State private var recordingService = AudioRecordingService()` でインスタンス化
- マイクボタンは `.onLongPressGesture(minimumDuration: 0, pressing:)` を使って長押し検出
  - `pressing == true` → `recordingService.startRecording()`
  - `pressing == false` → `Task { await recordingService.stopRecording() }`
- 録音中は他のUI操作（送信ボタンなど）を `disabled(true)` にすること
- `recordingService.errorMessage` が非nilの場合はアラートで表示すること
- 既存の送信ボタンのアクションを変更しないこと（後のステップで拡張）

---

## ステップ4：送信処理の更新

### 対象ファイル
既存のアラーム送信ViewModel（または送信処理が書かれたファイル）を探して開くこと。

### 変更内容

送信ボタンタップ時の処理を以下の順序に更新する：

```swift
func sendAlarm() async {
    // 1. （既存）バリデーション

    // 2. 録音がある場合のみアップロード
    var audioURL: String? = nil
    if recordingService.recordedFileURL != nil {
        do {
            let eventId = UUID().uuidString // 送信前にeventIdを確定させる
            audioURL = try await recordingService.uploadRecording(eventId: eventId)
        } catch {
            // エラー表示して送信を中断
            self.errorMessage = error.localizedDescription
            return
        }
    }

    // 3. InboxEvent を生成（audioURL を含める）
    // 4. （既存）Firestoreに保存・FCM通知送信
    // 5. （既存）送信完了処理
}
```

### 注意事項
- アップロード中はローディングインジケーターを表示すること
- 既存の送信フローのエラーハンドリングを壊さないこと

---

## ステップ5：NotificationServiceExtensionの更新

### 対象ファイル
既存の `NotificationService.swift`（NotificationServiceExtension内）を探して開くこと。

### 変更内容

`didReceive` メソッド内に以下の処理を追加する：

```swift
// audioURLがpayloadに含まれている場合、音声ファイルをダウンロードして通知に添付
if let audioURLString = bestAttemptContent.userInfo["audioURL"] as? String,
   let audioURL = URL(string: audioURLString) {
    
    do {
        // 1. URLSessionで音声ファイルをダウンロード（同期的に待機）
        let (tempURL, _) = try await URLSession.shared.download(from: audioURL)
        
        // 2. 一時ディレクトリに適切な拡張子でコピー（.m4a）
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try FileManager.default.copyItem(at: tempURL, to: destination)
        
        // 3. UNNotificationAttachment として添付
        let attachment = try UNNotificationAttachment(
            identifier: "recording",
            url: destination,
            options: nil
        )
        bestAttemptContent.attachments = [attachment]
        bestAttemptContent.sound = nil // デフォルト音を無効化
        
    } catch {
        // ダウンロード失敗時はデフォルト音のままにする（フォールバック）
        // エラーログを残すこと
        print("[NotificationService] Audio download failed: \(error)")
    }
}
```

### 注意事項
- 既存の処理（タイトル・ボディの変更など）を壊さないこと
- `contentHandler(bestAttemptContent)` の呼び出しは既存の位置を維持すること
- FCM通知のpayloadに `audioURL` が含まれるよう、送信側（ステップ4）でFirestoreに保存したURLをFCMのdata payloadに含めること
- ダウンロード失敗は必ずフォールバック（デフォルト音）で処理すること

---

## ステップ6：RingingScreenの更新

### 対象ファイル
既存の `RingingScreen`（またはそれに相当するView/ViewModel）を探して開くこと。

### 変更内容

RingingScreenが表示されたとき、`audioURL` の有無に応じて再生する音声を切り替える。

```swift
// RingingScreenViewModel（または相当するクラス）に追加

private var audioPlayer: AVAudioPlayer?
private var audioPlayerItem: AVPlayerItem?
private var player: AVPlayer?

func startAudio(audioURL: String?) {
    if let urlString = audioURL, let url = URL(string: urlString) {
        // 録音音声をURLからストリーミング再生（ループ）
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                await MainActor.run {
                    self.playLocalFile(url: localURL, loop: true)
                }
            } catch {
                // ダウンロード失敗時はデフォルト音にフォールバック
                await MainActor.run {
                    self.playDefaultAlarm()
                }
            }
        }
    } else {
        // 録音なし → デフォルトアラーム音を再生
        playDefaultAlarm()
    }
}

private func playLocalFile(url: URL, loop: Bool) {
    // AVAudioPlayer で再生、loop時は numberOfLoops = -1
    setupAudioSession()
    do {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = loop ? -1 : 0
        audioPlayer?.play()
    } catch {
        playDefaultAlarm()
    }
}

private func playDefaultAlarm() {
    // 既存のデフォルトアラーム音再生処理を呼び出す（既存コードを流用）
}

private func setupAudioSession() {
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
}

/// 「起きた！」または「スヌーズ」タップ時に呼び出す
func stopAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
}
```

### 注意事項
- 既存の「起きた！」「スヌーズ」ボタンのアクション内で `stopAudio()` を呼び出すこと
- RingingScreenが `onDisappear` したときも `stopAudio()` を呼ぶこと（画面遷移時の音漏れ防止）
- AVAudioSession の設定は既存の設定と競合しないよう注意すること

---

## ステップ7：マイク権限の確認

### 対象ファイル
既存の権限リクエスト処理（オンボーディングまたはInfo.plist）を確認すること。

### 確認・追加事項

**Info.plist に以下のキーが存在するか確認：**
```
NSMicrophoneUsageDescription
```
存在しない場合は追加する。値の例：「友達へのアラームに音声メッセージを録音するために使用します」

**オンボーディングのステップ4（権限リクエスト）に既にマイクが含まれているか確認：**
- 含まれていない場合、`AVAudioApplication.requestRecordPermission` のリクエストを追加すること
- 含まれている場合は変更不要

---

## 実装完了チェックリスト

実装が完了したら以下を全て確認すること：

- [ ] ビルドエラーが0件
- [ ] 既存のアラーム送信フローが壊れていない
- [ ] 録音なしで送信した場合、従来通りデフォルト音で動作する
- [ ] 録音ありで送信した場合、`InboxEvent.audioURL` にURLが保存される
- [ ] `recordings/{eventId}.m4a` がFirebase Storageに保存される
- [ ] 結合後のファイルが30秒以内に収まっている
- [ ] RingingScreen表示時に音声が再生される
- [ ] 「起きた！」「スヌーズ」タップで音声が停止する
- [ ] 録音なし時はデフォルト音にフォールバックする
- [ ] 一時ファイルが適切にクリーンアップされる
- [ ] マイク権限なしの場合にエラーメッセージが表示される

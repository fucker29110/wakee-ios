# Wakee - アプリ仕様書

## アプリ概要

**Wakee**は「友達を起こす」をコンセプトにしたソーシャルアラームアプリです。友達にアラームを送り、起きたかどうかをリアルタイムで確認できます。起床・スヌーズなどのアクションはソーシャルフィードに共有され、友達同士で朝の習慣を楽しく続けられます。

- **プラットフォーム**: iOS (SwiftUI)
- **バックエンド**: Firebase (Auth / Firestore / Storage / Cloud Messaging)
- **デザイン**: ダークテーマ、アクセントカラー #FF6B35（オレンジ）

---

## 主要機能

### 1. アラーム送信・受信

Wakeeの中核機能。友達を選んでアラーム時刻を設定し、メッセージ付きで起こすことができます。

**送信側の流れ:**
1. フレンドリストから起こしたい友達を選択（複数選択可）
2. アラーム時刻を設定
3. 任意でメッセージを添付（最大200文字）
4. 送信 → ロック画面にLive Activityが表示され、友達のステータスをリアルタイムで確認

**受信側の流れ:**
1. プッシュ通知でアラーム受信
2. 設定時刻にフルスクリーンのアラーム画面が起動（パルスアニメーション + サウンド + バイブレーション）
3. 「起きた！」→ 起床記録がフィードに投稿
4. 「スヌーズ」→ 設定分数後に再度アラーム（スヌーズ回数がカウントされる）

**Live Activity:**
- 送信者: 各受信者のステータス（pending / ringing / achieved / snoozed / ignored）をロック画面で確認
- 受信者: アラーム情報（送信者名・時刻・メッセージ）をロック画面に表示

---

### 2. ソーシャルフィード（ホーム）

友達のアクティビティがタイムラインで流れます。

**アクティビティの種類:**
| タイプ | 表示 | アイコン |
|--------|------|----------|
| sent | アラームを送った | alarm |
| achieved | 起きた! | sun.max.fill |
| snoozed | スヌーズした | moon.zzz.fill |
| rejected | 二度寝した... | bed.double.fill |
| repost | リポスト | arrow.2.squarepath |

**フィードカードの情報:**
- アクターのアバター・ユーザー名
- アクティビティ内容（例: 「が起きた!」）
- アラーム時刻 + 経過時間（例: 「午前7:30 · 5分前」）
- ターゲットユーザー（例: 「by @username」）
- 任意のメッセージ（8文字以上は折りたたみ）
- コメント数・リポストボタン

---

### 3. ストーリー

12時間で消える短いテキスト投稿。フィードの上部に横スクロールで表示されます。

- 自分のストーリーを投稿・編集・削除
- 友達のストーリーを閲覧（未読インジケーター付き）
- 12時間後に自動消去

---

### 4. コメント・リポスト

**コメント:**
- フィードの各アクティビティにコメント可能
- 投稿詳細画面でコメント一覧を表示
- 公開範囲はアクターまたはターゲットのフレンドに限定

**リポスト:**
- 友達のアクティビティをリポスト（任意のコメント付き）
- Twitter/X風のリポスト表示（元投稿カード内包）

---

### 5. フレンドシステム

**フレンドを探す（タブ1）:**
- 友達招待バナー（プロフィールリンクのシェア・コピー）
- おすすめ友達リスト（共通フレンド数順）

**フレンドリスト（タブ2）:**
- 承認済みフレンド一覧
- チャットボタン付き

**フレンド追加フロー:**
1. ユーザー名で検索（ツールバーの検索アイコン）
2. フレンド申請を送信
3. 相手の通知画面に表示 → 承認 or 拒否
4. 承認後、フレンドとしてアラーム送信・チャットが可能に

**プロフィール画面:**
- アバター・表示名・ユーザー名・自己紹介・場所
- ストリーク（連続起床日数）
- アクション: メッセージ送信 / フレンド申請 / ブロック

---

### 6. チャット（DM）

フレンド同士の1対1メッセージング。

- チャットリスト: 最新メッセージ順、未読バッジ付き
- チャットルーム: リアルタイムメッセージング
- メッセージ上限: 直近50件を表示
- 未読カウントはチャットを開くとリセット

---

### 7. 通知

**通知の種類:**
| タイプ | 内容 |
|--------|------|
| alarm_received | アラーム受信 |
| friend_request | フレンド申請 |
| friend_accepted | フレンド承認 |
| comment | コメント |
| repost | リポスト |

- アプリ内通知画面で一覧表示（未読/既読の区別）
- フレンド申請にはインラインの承認/拒否ボタン
- プッシュ通知でリアルタイム受信
- 通知タップでディープリンク遷移

---

### 8. プロフィール

**自分のプロフィール:**
- アバター・表示名・ユーザー名・自己紹介・場所
- 統計: フレンド数 / 送信アラーム数 / 起床達成数 / ストリーク
- 直近20件のアクティビティ履歴

**プロフィール編集:**
- 表示名・ユーザー名・自己紹介・場所の変更
- アバター画像のアップロード（Firebase Storage）
- ユーザー名の重複チェック

**設定:**
- 検索可能性のON/OFF
- ブロックユーザー管理
- ログアウト

---

## 認証・オンボーディング

### 認証方法（4種類）

1. **Google サインイン**
2. **Apple サインイン**
3. **メール/パスワード**（新規登録 & ログイン）
4. **電話番号認証**（SMS認証コード）

### ログイン画面のフロー

1. **Welcome画面**: 「登録する」ボタン + 「ログイン」リンク
2. **認証方法選択画面**: Google / Apple / 電話番号 / メール の4つのボタン
3. メール選択時はフォームが展開表示

### オンボーディング（新規登録後）

| ステップ | 内容 |
|----------|------|
| 1 | 名前入力 + アバター写真設定 |
| 2 | ユーザー名の選択（バリデーション + 重複チェック + ランダム生成） |
| 3 | フレンドを探す（検索 + おすすめ + プロフィールリンクシェア） |
| 4 | 権限リクエスト（通知 / カメラ / マイク） |

---

## ナビゲーション

### メインタブ（5つ）

| タブ | アイコン | 内容 |
|------|----------|------|
| ホーム | house.fill | フィード + ストーリー + 通知へのリンク |
| フレンド | person.2.fill | フレンド探す + フレンドリスト |
| アラーム | alarm（中央グラデーション） | アラーム作成画面 |
| チャット | bubble.left.and.bubble.right.fill | チャットリスト |
| プロフィール | person.fill | 自分のプロフィール |

---

## デザインシステム

### カラーパレット

| 名前 | カラーコード | 用途 |
|------|------------|------|
| Background | #0A0A0A | 背景 |
| Surface | #1A1A1A | カード・入力欄 |
| Accent | #FF6B35 | ボタン・ハイライト |
| Primary | #FFFFFF | メインテキスト |
| Secondary | #9CA3AF | サブテキスト |
| Border | #2A2A2A | ボーダー |
| Danger | #EF4444 | エラー・警告 |

### タイポグラフィ

| サイズ | 値 | 用途 |
|--------|-----|------|
| xxl | 48px | ロゴ |
| xl | 24px | 画面タイトル |
| lg | 20px | セクションヘッダー |
| md | 16px | 本文 |
| sm | 14px | サブテキスト |
| xs | 12px | キャプション |

### スペーシング

xs: 4px / sm: 8px / md: 16px / lg: 24px / xl: 32px

### 角丸

sm: 8px / md: 12px / lg: 24px / full: 999px（円形）

---

## データモデル

### ユーザー (AppUser)
```
uid, displayName, username, photoURL, bio, location,
streak, settings {searchable, blocked[]},
fcmToken, onboardingCompleted, createdAt, updatedAt
```

### アクティビティ (Activity)
```
type, actorUid, targetUid, relatedEventId, time,
streak, message, snoozeCount, displayMessage,
visibility[], repostSourceId, repostComment,
commentCount, lastCommentAt, createdAt
```

### インボックスイベント (InboxEvent)
```
senderUid, senderName, time, label, message,
repeat[], snoozeMin, status, audioURL,
scheduledDate, createdAt
```

### チャット (Chat)
```
users[], userMap{}, lastMessage, lastMessageAt,
unreadCount{}
```

### メッセージ (Message)
```
senderUid, text, type, createdAt
```

### ストーリー (Story)
```
authorUid, text, readBy[], createdAt, expiresAt
```

### フォローリクエスト (FollowRequest)
```
fromUid, toUid, fromName, status, createdAt
```

### 通知 (AppNotification)
```
type, title, body, senderUid, senderName,
relatedId, read, createdAt
```

---

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| フレームワーク | SwiftUI |
| アーキテクチャ | MVVM + @Observable |
| 認証 | Firebase Auth (Google / Apple / Email / Phone) |
| データベース | Cloud Firestore |
| ストレージ | Firebase Storage |
| 通知 | Firebase Cloud Messaging + APNs |
| Live Activity | ActivityKit |
| メディア | AVFoundation (アラーム音・バイブレーション) |
| 画像選択 | PhotosUI (PhotosPicker) |

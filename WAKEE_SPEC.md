# Wakee - アプリ完全仕様書

Swift (SwiftUI + Firebase) ネイティブ iOS アプリへの移植用リファレンス。

---

## 1. アプリ概要

**Wakee** は友達同士でアラームを送り合える SNS 型アラームアプリ。
友達にアラームを仕掛け、起きた結果（即起き・スヌーズ・拒否など）がフィードに流れる。

### テーマ・デザイン
- **ダークテーマ固定**
- Background: `#0A0A0A`, Surface: `#1A1A1A`, SurfaceVariant: `#2A2A2A`
- Accent: `#FF6B35` (オレンジ), AccentEnd: `#FF8F65` (グラデーション終端)
- Primary Text: `#FFFFFF`, Secondary Text: `#9CA3AF`
- Success: `#22C55E`, Danger: `#EF4444`, Warning: `#F59E0B`
- Border: `#333333`
- Tab Active: `#FFFFFF`, Tab Inactive: `#6B7280`

---

## 2. Firebase 設定

### プロジェクト情報
```
projectId: alarmx-app-7afe1
storageBucket: alarmx-app-7afe1.firebasestorage.app
messagingSenderId: 793164138726
```

### 認証方法 (Firebase Authentication)
1. **Google Sign-In** — webClientId + iOS/Android clientId
2. **Apple Sign-In** — OAuthProvider('apple.com'), nonce 必須
3. **メール/パスワード** — createUserWithEmailAndPassword / signInWithEmailAndPassword
4. **電話番号 (SMS)** — PhoneAuthProvider + reCAPTCHA 検証

全認証方法は成功後 `createOrGetUserDocument()` を呼び、Firestore にユーザードキュメントを作成/取得する。

### Firebase Storage パス
- プロフィール画像: `avatars/{uid}`
- アラーム音声: `alarm_audio/{uid}_{timestamp}.m4a`

---

## 3. ナビゲーション構造

```
RootStack (Native Stack)
├── Auth (未ログイン時)
│   └── LoginScreen
├── Main (ログイン後) — Bottom Tab Navigator (5タブ)
│   ├── HomeTab (Stack)
│   │   ├── HomeScreen (フィード + ストーリー)
│   │   ├── PostDetailScreen (投稿詳細 + コメント)
│   │   ├── FriendProfileScreen (他ユーザープロフィール)
│   │   └── NotificationScreen (通知一覧)
│   ├── FriendsTab (Stack)
│   │   ├── FriendsListScreen (フレンド / リクエスト / 検索)
│   │   └── FriendProfileScreen
│   ├── SendAlarmTab (Stack) — 中央の特別ボタン
│   │   └── CreateAlarmScreen (アラーム作成・送信)
│   ├── ChatTab (Stack)
│   │   ├── ChatListScreen (チャット一覧)
│   │   └── ChatRoomScreen (1対1チャット)
│   └── ProfileTab (Stack)
│       ├── ProfileScreen (自分のプロフィール)
│       ├── ProfileEditScreen (プロフィール編集)
│       └── SettingsScreen (設定・ログアウト)
└── Ringing (フルスクリーンモーダル — アラーム鳴動画面)
```

### タブバーの特徴
- 中央の「SendAlarm」ボタンは浮き上がったグラデーション円形ボタン
- HomeTab ヘッダー右にベル型通知アイコン（未読バッジ付き）
- ChatTab に未読メッセージ数バッジ
- ヘッダータイトルは "Wakee"（太字 900, 24px）

---

## 4. 全画面仕様

### 4.1 LoginScreen
**目的:** 多方式認証（Google / Apple / 電話番号 / メール）

**UI:**
- ロゴ: グラデーション円形にアラームアイコン + "Wakee" + "友達に起こしてもらおう"
- モード切り替え: ログイン / 新規登録
- プロバイダーボタン4つ（Google, Apple※iOS, 電話番号, メール）
- 電話番号: ボトムシートモーダル（番号入力 → SMS コード入力）
- メール: 専用フォーム画面（displayName※新規のみ, email, password）

**ロジック:**
- Google: `expo-auth-session` → idToken/accessToken → `GoogleAuthProvider.credential()` → `signInWithCredential()`
- Apple: nonce 生成 → `AppleAuthentication.signInAsync()` → `OAuthProvider('apple.com').credential()` → `signInWithCredential()`
- 電話番号: reCAPTCHA → verificationId → SMS コード → `PhoneAuthProvider.credential()` → `signInWithCredential()`
- メール: `signInWithEmailAndPassword()` or `createUserWithEmailAndPassword()`
- 全方式共通: 成功後 `createOrGetUserDocument()` でユーザードキュメント作成/取得

**初回ユーザー作成時のデフォルト値:**
```
displayName: Firebase Auth の displayName or "ユーザー"
username: displayName の英数字小文字化 + "_" + uid先頭4文字 (例: "user_ab12")
bio: ""
location: ""
streak: 0
settings: { searchable: true, blocked: [] }
```

---

### 4.2 HomeScreen (フィード)
**目的:** ストーリー + アクティビティフィード

**UI:**
- **ストーリー行** (横スクロール):
  - 自分のアイコン（ストーリーなし: "+" バッジ付き）
  - フレンドのアイコン（未読: アクセントグラデーションリング, 既読: グレーリング）
  - ストーリーテキストの吹き出しプレビュー（最大2行）
  - 全アイコンは下揃え (`alignItems: 'flex-end'`)
- **フィードカード** (FlatList):
  - アバター + ユーザーネーム（太字）+ 表示名（グレー）+ "・" + 経過時間
  - アクティビティラベル（displayName を使用）
  - メッセージ引用（イタリック）
  - リポスト引用カード（リポスト元のテキスト + ユーザーネーム）
  - フッター: コメント数 + リポストボタン
- **リポストモーダル**: テキスト入力 + 引用カード + 投稿ボタン
- **ストーリー作成/編集モーダル**: テキスト入力（最大100文字）
- **ストーリー閲覧モーダル**: フルスクリーン横ページング

**表示名ルール:**
- カードヘッダー: `username` 表示（@ なし）
- アクティビティテキスト: `displayName` 使用
- リポスト引用: `username` 表示（@ なし）

**データ取得:**
- `activityService.subscribeFeed(uid)` — visibility に自分の UID が含まれるアクティビティ（最大30件）
- `activityService.getUsersForActivities()` — アクター/ターゲットのユーザー情報バッチ取得
- フィード表示時に `sent` と `received_wakeup` タイプは除外

**ナビゲーション:**
- カードタップ → PostDetailScreen
- アバタータップ → FriendProfileScreen
- ヘッダーベルアイコン → NotificationScreen

---

### 4.3 PostDetailScreen (投稿詳細)
**目的:** アクティビティの詳細表示 + コメント

**UI:**
- 投稿カード: アバター（タップでプロフィール遷移）+ ユーザーネーム + 表示名 + 経過時間
- アクティビティラベル + メッセージ引用
- リポスト元カード（repost タイプの場合）
- コメント数
- コメント一覧: アバター + 投稿者名 + テキスト + 経過時間
- コメント入力欄（最大200文字）+ 送信ボタン
- 権限なしの場合: ロックアイコン + "この投稿にはコメントできません"

**コメント権限:** `activity.visibility` に自分の UID が含まれる場合のみ

**アクティビティラベル生成ロジック:**
```
displayMessage があればそれを使用、なければ type で分岐:
- sent:            "{actorName} が {targetName} にアラームを仕掛けました"
- received_wakeup: "{actorName} が {targetName} に起こされました（{time}）"
- achieved:        "{actorName} が {time}に起きました!"
- rejected:        "{actorName} が アラームを秒で拒否りました"
- snoozed:         "{actorName} が {snoozeCount}回スヌーズしてやっと起きました"
- repost:          repostComment or "{actorName} がリポストしました"
```

---

### 4.4 NotificationScreen (通知)
**目的:** アプリ内通知の一覧表示

**UI:**
- 通知アイテム: アバター + タイトル + 本文 + 経過時間
- 未読アイテムは薄オレンジ背景 (`rgba(255, 107, 53, 0.06)`)
- 空状態: ベルオフアイコン + "通知はまだありません"

**ロジック:**
- 画面表示時に全通知を既読に更新
- タイトル/本文中の `senderName` を `username` に動的置換して表示
- 全通知タイプでタップ → FriendProfileScreen へ遷移

---

### 4.5 FriendsListScreen (フレンド管理)
**目的:** フレンド一覧、リクエスト管理、ユーザー検索

**UI (3タブ切り替え):**
1. **フレンド**: FriendCard の FlatList (アバター + displayName + @username)
2. **リクエスト**: RequestCard の FlatList (アバター + fromName + 承認/拒否ボタン) + 未読バッジ
3. **検索**: テキスト入力 + 検索ボタン + 結果リスト（状態バッジ: 友達/申請済み/申請する）

**検索:** `friendService.searchByUsername()` — ユーザーネーム完全一致

---

### 4.6 FriendProfileScreen (他ユーザープロフィール)
**目的:** 他ユーザーのプロフィール表示 + 友達関係管理

**UI:**
- アバター (80px) + displayName + @username
- bio カード（存在時）
- location 行（存在時）
- ステータスに応じたアクションボタン:
  - `friend`: "フレンド" バッジ（緑）+ "メッセージを送る" ボタン
  - `sent`: "申請済み" バッジ
  - `received`: "フォロー申請が届いています" + 承認/拒否ボタン
  - `none`: "フレンドリクエストを送る" ボタン
- ブロックボタン（確認ダイアログ付き）

**DM 遷移ロジック:**
- `chatService.getOrCreateChat(myUid, friendUid)` — チャットID = UID をソートして結合
- 存在しないチャットは `setDoc` で新規作成（Firestore の読み取りルールで permission-denied になるため try/catch）
- ChatTab の ChatRoom に cross-tab ナビゲーション

---

### 4.7 CreateAlarmScreen (アラーム作成)
**目的:** フレンドにアラームを送信

**UI:**
- **宛先選択**: フレンドリスト（チェックボックス）+ 選択数バッジ
- **時間設定**: カスタムスクロールホイール (時:0-23, 分:0-59)
  - 残り時間表示 "Ring in Xh Ym"
  - 5アイテム表示、中央スナップ、非中央アイテムは透明度/スケール変化
- **メッセージ**: テキスト入力（最大200文字）+ テンプレート5種
  - "起きて！", "そろそろ起きる時間だよ", "おはよう！", "遅刻するよ！", "頑張って！"
- **ボイスメッセージ**: マイクボタン → RecordingModal（最大10秒）
- **送信ボタン**: グラデーション + 選択人数表示

**送信ロジック:**
1. 音声がある場合: Firebase Storage にアップロード → URL 取得
2. 選択した各フレンドに `alarmService.sendAlarm()` — 受信者の `inbox` サブコレクションにドキュメント作成
3. `activityService.record()` — `sent` タイプのアクティビティを記録（visibility = 自分のフレンド全員 + 自分）

---

### 4.8 RingingScreen (アラーム鳴動)
**目的:** フルスクリーンアラーム画面

**Route パラメータ:**
```
eventId, senderName, senderUid, time, message, snoozeMin, receiverUid, snoozeCount?, audioURL?
```

**UI:**
- グラデーション背景（下部がオレンジ）
- パルスアニメーションするアラームアイコン
- "{senderName} からのアラーム"
- 大きな時刻表示 (64px)
- メッセージ引用（存在時）
- スヌーズボタン（グレー）+ 停止ボタン（オレンジグラデーション）

**副作用 (画面表示時):**
1. バイブレーションパターン: `[0, 500, 200, 500]` 繰り返し
2. アラーム音再生（audioURL があればリモート、なければデフォルト音）— ループ、サイレントモードでも再生
3. 通知履歴作成（初回鳴動時のみ、スヌーズ後は作成しない）

**停止ボタン → アクティビティ記録ロジック:**
```
経過時間 < 5秒 → type: 'rejected', メッセージ: "アラームを秒で拒否りました"
スヌーズあり    → type: 'snoozed', メッセージ: "{snoozeCount}回スヌーズしてやっと起きました"
それ以外        → type: 'achieved', メッセージ: "{time}に起きました!"
```

**スヌーズボタン:**
- `alarmService.snoozeAlarm()` — inbox ステータス更新 + 新しい scheduledDate 設定
- ローカル通知を再スケジュール（snoozeCount インクリメント）

---

### 4.9 ChatListScreen (チャット一覧)
**目的:** 1対1チャットの一覧

**UI:**
- チャットアイテム: アバター + 相手の名前 + 最終メッセージ + 時刻 + 未読バッジ（グラデーション）
- 空状態: "チャットがまだありません"

**データ:** `chatService.subscribeChats(uid)` — `userMap` に自分が含まれるチャットをリアルタイム購読

---

### 4.10 ChatRoomScreen (チャット)
**目的:** 1対1メッセージング

**UI:**
- メッセージリスト（反転 FlatList）:
  - 自分: グラデーションバブル（右寄せ）+ 時刻
  - 相手: サーフェスバブル（左寄せ）+ アバター + 時刻
  - システム: 中央テキスト（`alarm_notification` タイプ）
- 入力欄: TextInput + 送信ボタン
- カスタムヘッダー: アバター + 名前（タップでプロフィール遷移）

**ロジック:**
- `chatService.subscribeMessages(chatId)` — 最新50件をリアルタイム購読
- `chatService.sendMessage()` — メッセージ追加 + lastMessage/unreadCount 更新
- `chatService.markAsRead()` — 画面フォーカス時に未読リセット

---

### 4.11 ProfileScreen (自分のプロフィール)
**目的:** 自分のプロフィール表示 + 統計 + アクティビティ履歴

**UI:**
- アバター (80px) + displayName + @username + bio
- 統計カード: フレンド数（タップで FriendsTab 遷移）| 起こした数
- "プロフィールを編集" ボタン
- "設定" ボタン
- アクティビティ履歴: バッジ（タイプラベル）+ 時刻 + メッセージ + 経過時間

**アクティビティ履歴:** `sent` と `received_wakeup` は除外して表示

---

### 4.12 ProfileEditScreen (プロフィール編集)
**目的:** プロフィール情報の編集

**UI:**
- アバター（タップで画像選択 → アップロード、進捗バー付き）
- displayName 入力（最大30文字）
- username 入力（@プレフィックス表示、バリデーション付き）
- bio テキストエリア（最大200文字、文字数カウンター）
- location 入力（最大50文字）
- 保存ボタン（グラデーション）

**username バリデーション:**
- 正規表現: `/^[a-z0-9_]{3,20}$/`
- 重複チェック: `isUsernameAvailable(username, myUid)`

---

### 4.13 SettingsScreen (設定)
**目的:** ログアウト

**UI:** ログアウトボタンのみ（danger カラー + アイコン）

---

## 5. Firestore データモデル

### 5.1 `users/{uid}`
```
{
  displayName: string
  username: string              // ユニーク、小文字英数字+アンダースコア
  photoURL: string | null
  bio: string
  location: string
  streak: number                // 現在未使用（UI から削除済み）
  settings: {
    searchable: boolean
    blocked: string[]           // ブロックした UID 一覧
  }
  fcmToken: string?             // Expo Push Token
  createdAt: Timestamp
  updatedAt: Timestamp
}
```

### 5.2 `users/{uid}/inbox/{eventId}`
```
{
  senderUid: string
  senderName: string
  time: string                  // "07:30" 形式
  label: string
  message: string
  repeat: WeekDay[]             // 現在未使用
  snoozeMin: number             // 5, 10, 15, 30
  audioURL: string | null
  status: 'pending' | 'scheduled' | 'rung' | 'dismissed' | 'snoozed'
  scheduledDate: Timestamp      // 次回アラーム日時
  createdAt: Timestamp
}
```

### 5.3 `users/{uid}/notifications/{notifId}`
```
{
  type: 'alarm_received' | 'friend_request' | 'friend_accepted'
  title: string
  body: string
  senderUid: string
  senderName: string
  relatedId: string | null      // requestId 等
  read: boolean
  createdAt: Timestamp
}
```

### 5.4 `followRequests/{reqId}`
```
{
  fromUid: string
  toUid: string
  fromName: string
  status: 'pending' | 'accepted' | 'rejected'
  createdAt: Timestamp
}
```

### 5.5 `friendships/{fsId}`
ID = UID2つをソートして `_` で結合（例: `abc_xyz`）
```
{
  users: [string, string]       // ソート済み UID ペア
  userMap: { uid1: true, uid2: true }  // クエリ用
  createdAt: Timestamp
}
```

### 5.6 `activities/{actId}`
```
{
  type: 'sent' | 'received_wakeup' | 'achieved' | 'rejected' | 'snoozed' | 'repost'
  actorUid: string
  targetUid: string | null
  relatedEventId: string | null
  time: string                  // "07:30" 形式
  streak: number | null         // 現在未使用
  message: string | null
  snoozeCount: number | null
  displayMessage: string | null // 自由形式のメッセージ（あればラベル生成に優先）
  repostSourceId: string?       // リポスト元アクティビティ ID
  repostComment: string?        // リポスト時のコメント
  visibility: string[]          // 閲覧可能な UID 一覧
  commentCount: number          // コメント数（デフォルト 0）
  lastCommentAt: Timestamp?
  createdAt: Timestamp
}
```

### 5.7 `activities/{actId}/comments/{commentId}`
```
{
  authorId: string
  text: string
  visibilityBasis: 'actor_friends' | 'target_friends'
  createdAt: Timestamp
}
```

### 5.8 `stories/{storyId}`
```
{
  authorUid: string
  text: string                  // 一言テキスト（最大100文字）
  readBy: string[]              // 既読ユーザー UID 一覧
  createdAt: Timestamp
  expiresAt: Timestamp          // 作成から12時間後
}
```

### 5.9 `chats/{chatId}`
ID = UID2つをソートして `_` で結合（例: `abc_xyz`）
```
{
  users: [string, string]
  userMap: { uid1: true, uid2: true }
  lastMessage: string
  lastMessageAt: Timestamp
  unreadCount: { uid1: number, uid2: number }
}
```

### 5.10 `chats/{chatId}/messages/{msgId}`
```
{
  senderUid: string
  text: string
  type: 'text' | 'alarm_notification'
  createdAt: Timestamp
}
```

---

## 6. Firestore セキュリティルール

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() { return request.auth != null; }
    function isOwner(uid) { return isAuth() && request.auth.uid == uid; }

    // users/{uid}
    //   read: 認証済みなら誰でも
    //   create/update: 本人のみ
    //   delete: 不可
    //   inbox/{eventId}: read/update/delete=本人, create=認証済み
    //   notifications/{notifId}: read/update/delete=本人, create=認証済み

    // followRequests/{reqId}
    //   read: 送信者 or 受信者
    //   create: 自分が fromUid
    //   update: 受信者のみ（承認/拒否）
    //   delete: 送信者 or 受信者

    // friendships/{fsId}
    //   read: userMap に自分が含まれる
    //   create: 認証済み
    //   update/delete: userMap に自分が含まれる

    // activities/{actId}
    //   read: visibility に含まれる or actorUid or targetUid が自分
    //   create: actorUid が自分
    //   update: actorUid が自分 or visibility に含まれる（コメント数更新用）
    //   delete: actorUid が自分
    //   comments/{commentId}:
    //     read: 認証済み
    //     create: authorId が自分
    //     update/delete: authorId が自分

    // stories/{storyId}
    //   read: 認証済み
    //   create: authorUid が自分
    //   update: 認証済み（readBy 追加用）
    //   delete: authorUid が自分

    // chats/{chatId}
    //   read/update: userMap に自分が含まれる
    //   create: 認証済み
    //   delete: 不可
    //   messages/{msgId}:
    //     read: チャット参加者
    //     create: 参加者 かつ senderUid が自分
    //     update: 不可
    //     delete: 不可
  }
}
```

---

## 7. 通知・アラーム配信フロー

### アラーム送信フロー
```
1. CreateAlarmScreen で送信
2. alarmService.sendAlarm() → 受信者の inbox サブコレクションにドキュメント作成
3. activityService.record() → 'sent' アクティビティ記録（フレンド全員の visibility）
4. 受信側: useAlarms hook が inbox を購読 → pending イベント検出
5. notificationService.scheduleAlarm() → ローカル通知をバースト予約（30秒間隔×6回）
6. inbox ステータスを 'scheduled' に更新
7. 通知タップ or バックグラウンド受信 → RootNavigator が RingingScreen にナビゲート
```

### アラーム鳴動フロー
```
1. RingingScreen 表示
2. バイブレーション開始 + アラーム音再生（ループ、サイレントモード対応）
3. 通知履歴作成（初回のみ）

停止ボタン:
  - inbox ステータスを 'dismissed' に更新
  - アクティビティ記録（achieved/rejected/snoozed — 経過時間とスヌーズ回数で判定）
  - 画面を閉じる

スヌーズボタン:
  - inbox ステータスと scheduledDate を更新
  - ローカル通知を再予約（snoozeCount + 1）
  - 画面を閉じる
```

### Push 通知（バックグラウンド）
- Expo TaskManager でバックグラウンドタスク登録
- Push 通知受信 → `alarm_incoming` カテゴリの場合、ローカル通知をバースト予約
- フォアグラウンド時: `alarm_incoming` バナーは抑制（RingingScreen に直接遷移）

---

## 8. ストーリー機能

- 1ユーザー最大1つのアクティブストーリー
- 有効期間: 12時間
- テキストのみ（最大100文字）
- 投稿時に既存ストーリーは自動削除
- 閲覧すると `readBy` 配列に UID 追加
- フレンドのストーリーのみ表示（Firestore クエリで `authorUid in friendUids`、30件ずつチャンク）

---

## 9. リポスト機能

- フィードのアクティビティに対して「リポスト」可能
- リポスト時にコメントテキスト追加可（最大200文字）
- `activities` コレクションに `type: 'repost'` で新規ドキュメント作成
- `repostSourceId` で元アクティビティを参照
- 表示時に元アクティビティの内容を引用カードで表示

---

## 10. コメント機能

- アクティビティ詳細画面（PostDetailScreen）でコメント投稿可能
- `activity.visibility` に自分の UID が含まれる場合のみコメント可
- コメント追加時に親アクティビティの `commentCount` をインクリメント
- リアルタイム購読（`createdAt` 昇順）

---

## 11. ブロック機能

- FriendProfileScreen からブロック可能（確認ダイアログ付き）
- `users/{uid}.settings.blocked` 配列に相手の UID を追加
- ブロック後は検索・フォロー申請不可（アプリ側でフィルタ）

---

## 12. キャッシュ戦略

- `activityService` にインメモリの `userCache` (Map) を保持
- UID → `{ displayName, photoURL, username }` のマッピング
- セッション中の重複 Firestore 読み取りを防止
- `getUsersForActivities()`, `getDisplayNames()`, `getUserInfoByUids()` で共有

---

## 13. Swift 移植時の注意点

1. **Firebase iOS SDK** を使用（Swift Package Manager でインストール）
2. **GoogleService-Info.plist** を Xcode プロジェクトに追加
3. **認証**: FirebaseUI or 直接 `Auth.auth().signIn(with:)` を使用
4. **Firestore リアルタイムリスナー**: `.addSnapshotListener()` で同等の機能
5. **ローカル通知**: `UNUserNotificationCenter` でスケジュール
6. **バイブレーション**: `AudioServicesPlaySystemSound` or `UIImpactFeedbackGenerator`
7. **音声再生**: `AVAudioPlayer` でループ再生 + サイレントモード対応
8. **音声録音**: `AVAudioRecorder` (最大10秒)
9. **画像ピッカー**: `PHPickerViewController`
10. **ストレージアップロード**: Firebase Storage の `putData()` / `putFile()`
11. **チャット ID 生成**: 2つの UID をソートして `_` で結合（既存データと互換性維持）
12. **セキュリティルール**: そのまま流用可能（フロントエンド変更のみ）

# WakeeNotificationService - Xcode セットアップ手順

## 1. Notification Service Extension ターゲット追加

1. Xcode でプロジェクトを開く
2. File → New → Target
3. 「Notification Service Extension」を選択
4. Product Name: `WakeeNotificationService`
5. Language: Swift
6. 「Finish」をクリック
7. 自動生成された `NotificationService.swift` を削除し、このディレクトリの `NotificationService.swift` に差し替え

## 2. App Groups 設定

### メインアプリ (Wakee)
1. プロジェクト設定 → Wakee ターゲット → Signing & Capabilities
2. 「+ Capability」→ 「App Groups」を追加
3. `group.com.wakee.shared` を追加

### Extension (WakeeNotificationService)
1. WakeeNotificationService ターゲット → Signing & Capabilities
2. 「+ Capability」→ 「App Groups」を追加
3. 同じ `group.com.wakee.shared` を追加

## 3. Entitlements 確認

- `Wakee.entitlements` に `com.apple.security.application-groups` が含まれていること
- `WakeeNotificationService.entitlements` に同じグループが含まれていること

## 4. Info.plist 確認

Extension の Info.plist に以下が設定されていること:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.usernotifications.service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
</dict>
```

## 5. デプロイメントターゲット

Extension のデプロイメントターゲットをメインアプリと同じに設定。

import Foundation

/// 通知タップ等のディープリンクを管理するシングルトン
@Observable
final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}

    /// 遷移先タブ（MainTabView が処理後 nil にリセット）
    var pendingTab: Int?

    /// ホームから特定の投稿詳細に遷移する場合の activityId
    var pendingActivityId: String?

    /// チャット通知タップ時の遷移先 chatId
    var pendingChatId: String?

    /// プロフィール遷移の共通判定
    /// 自分ならプロフィールタブへ遷移して false を返す。他人なら true を返す。
    func navigateToProfile(uid: String, myUid: String?) -> Bool {
        if uid == myUid {
            pendingTab = 4
            return false
        }
        return true
    }
}

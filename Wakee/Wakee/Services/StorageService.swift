import Foundation
import FirebaseStorage
import PhotosUI
import SwiftUI

final class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    private init() {}

    func uploadGroupImage(chatId: String, imageData: Data) async throws -> String {
        let ref = storage.reference().child("group_images/\(chatId)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadProfileImage(uid: String, imageData: Data) async throws -> String {
        let ref = storage.reference().child("avatars/\(uid)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

enum StorageError: LocalizedError {
    case uploadFailed
    var errorDescription: String? { LanguageManager.shared.l("service.upload_failed") }
}

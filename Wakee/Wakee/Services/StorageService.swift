import Foundation
import FirebaseStorage
import PhotosUI
import SwiftUI

final class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    private init() {}

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
    var errorDescription: String? { "アップロードに失敗しました" }
}

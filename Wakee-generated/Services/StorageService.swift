import Foundation
import FirebaseStorage
import PhotosUI
import SwiftUI

final class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    private init() {}

    func uploadProfileImage(uid: String, imageData: Data, onProgress: ((Double) -> Void)? = nil) async throws -> String {
        let ref = storage.reference().child("avatars/\(uid)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let uploadTask = ref.putData(imageData, metadata: metadata)

        if let onProgress {
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let percent = Double(progress.completedUnitCount) / Double(progress.totalUnitCount) * 100
                onProgress(percent)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            uploadTask.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: error ?? StorageError.uploadFailed)
                    }
                }
            }
            uploadTask.observe(.failure) { snapshot in
                continuation.resume(throwing: snapshot.error ?? StorageError.uploadFailed)
            }
        }
    }

    func uploadAlarmAudio(senderUid: String, audioData: Data) async throws -> String {
        let filename = "\(senderUid)_\(Int(Date().timeIntervalSince1970)).m4a"
        let ref = storage.reference().child("alarm_audio/\(filename)")
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mp4"

        _ = try await ref.putDataAsync(audioData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

enum StorageError: LocalizedError {
    case uploadFailed
    var errorDescription: String? { "アップロードに失敗しました" }
}

import SwiftUI
import PhotosUI
import UIKit

struct ProfileEditScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var usernameError: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var previewPhotoURL: String?
    @State private var cropImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Avatar
                VStack(spacing: AppTheme.Spacing.sm) {
                    AvatarView(
                        name: displayName,
                        photoURL: previewPhotoURL ?? authVM.user?.photoURL,
                        size: 80
                    )

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text("写真を変更")
                            .font(.system(size: AppTheme.FontSize.sm))
                            .foregroundColor(AppTheme.Colors.accent)
                    }

                    if isUploadingPhoto {
                        ProgressView()
                            .tint(AppTheme.Colors.accent)
                    }
                }

                // Fields
                VStack(spacing: AppTheme.Spacing.md) {
                    fieldRow(label: "表示名", text: $displayName)
                    fieldRow(label: "ユーザー名", text: $username)
                    if let error = usernameError {
                        Text(error)
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundColor(AppTheme.Colors.danger)
                    }
                    fieldRow(label: "自己紹介", text: $bio)
                    fieldRow(label: "場所", text: $location)
                }

                // Save button
                GradientButton(
                    title: "保存",
                    isLoading: isSaving
                ) {
                    saveProfile()
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCurrentValues() }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            loadImage(from: newValue)
        }
        .fullScreenCover(isPresented: Binding(
            get: { cropImage != nil },
            set: { if !$0 { cropImage = nil } }
        )) {
            if let image = cropImage {
                ImageCropView(
                    image: image,
                    onCrop: { croppedImage in
                        cropImage = nil
                        uploadCroppedImage(croppedImage)
                    },
                    onCancel: {
                        cropImage = nil
                    }
                )
            }
        }
    }

    private func fieldRow(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
            TextField(label, text: text)
                .textFieldStyle(DarkTextFieldStyle())
        }
    }

    private func loadCurrentValues() {
        guard let user = authVM.user else { return }
        displayName = user.displayName
        username = user.username
        bio = user.bio
        location = user.location
    }

    private func saveProfile() {
        guard let uid = authVM.user?.uid else { return }
        let trimmedUsername = username.lowercased().trimmingCharacters(in: .whitespaces)

        isSaving = true
        usernameError = nil

        Task {
            do {
                if trimmedUsername != authVM.user?.username {
                    let available = try await AuthService.shared.isUsernameAvailable(username: trimmedUsername, myUid: uid)
                    if !available {
                        await MainActor.run {
                            usernameError = "このユーザー名は既に使われています"
                            isSaving = false
                        }
                        return
                    }
                }

                var params: [String: Any] = [
                    "displayName": displayName,
                    "username": trimmedUsername,
                    "bio": bio,
                    "location": location
                ]
                if let photoURL = previewPhotoURL {
                    params["photoURL"] = photoURL
                }

                await authVM.updateProfile(params: params)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }
            await MainActor.run {
                cropImage = uiImage
            }
        }
    }

    private func uploadCroppedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85),
              let uid = authVM.user?.uid else { return }

        isUploadingPhoto = true

        Task {
            do {
                let url = try await StorageService.shared.uploadProfileImage(
                    uid: uid,
                    imageData: data
                )
                await MainActor.run {
                    previewPhotoURL = url
                    isUploadingPhoto = false
                }
            } catch {
                await MainActor.run { isUploadingPhoto = false }
                print("Upload error: \(error)")
            }
        }
    }
}

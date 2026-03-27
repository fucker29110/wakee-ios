import SwiftUI
import PhotosUI

struct NewGroupChatSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FriendsViewModel.self) private var friendsVM
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss

    var onCreated: (String) -> Void

    @State private var step = 1
    @State private var selectedUids: Set<String> = []
    @State private var groupName = ""
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var groupImageData: Data?
    @State private var isUploadingPhoto = false

    private var filteredFriends: [AppUser] {
        if searchText.isEmpty { return friendsVM.friends }
        let query = searchText.lowercased()
        return friendsVM.friends.filter {
            $0.displayName.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if step == 1 {
                    memberSelectionView
                } else {
                    groupNameView
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(step == 1 ? lang.l("group.select_members") : lang.l("group.set_name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == 2 {
                        Button(action: { step = 1 }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    } else {
                        Button(lang.l("common.cancel")) { dismiss() }
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == 1 {
                        Button(lang.l("group.next")) { step = 2 }
                            .foregroundColor(AppTheme.Colors.accent)
                            .disabled(selectedUids.count < 2)
                    }
                }
            }
        }
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
                        if let data = croppedImage.jpegData(compressionQuality: 0.85) {
                            groupImageData = data
                        }
                    },
                    onCancel: {
                        cropImage = nil
                    }
                )
            }
        }
    }

    // MARK: - Step 1: Member Selection

    private var memberSelectionView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.secondary)
                TextField(lang.l("group.search_friends"), text: $searchText)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surfaceVariant)
            .cornerRadius(AppTheme.BorderRadius.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.sm)

            if !selectedUids.isEmpty {
                Text(lang.l("group.selected_count", args: selectedUids.count))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.accent)
                    .padding(.top, AppTheme.Spacing.sm)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFriends) { friend in
                        Button {
                            toggleSelection(friend.uid)
                        } label: {
                            friendRow(friend: friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func friendRow(friend: AppUser) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.primary)
                Text("@\(friend.username)")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
            Image(systemName: selectedUids.contains(friend.uid) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(selectedUids.contains(friend.uid) ? AppTheme.Colors.accent : AppTheme.Colors.secondary)
                .font(.system(size: 22))
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 10)
    }

    private func toggleSelection(_ uid: String) {
        if selectedUids.contains(uid) {
            selectedUids.remove(uid)
        } else {
            selectedUids.insert(uid)
        }
    }

    // MARK: - Step 2: Group Name

    private var groupNameView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Group image picker
            VStack(spacing: AppTheme.Spacing.sm) {
                if let groupImageData, let uiImage = UIImage(data: groupImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.surfaceVariant)
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.3.fill")
                            .foregroundColor(AppTheme.Colors.accent)
                            .font(.system(size: 28))
                    }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text(lang.l("group.change_photo"))
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundColor(AppTheme.Colors.accent)
                }

                if isUploadingPhoto {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                }
            }
            .padding(.top, AppTheme.Spacing.md)

            // Selected members preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(friendsVM.friends.filter { selectedUids.contains($0.uid) }) { friend in
                        VStack(spacing: 4) {
                            AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 48)
                            Text(friend.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.secondary)
                                .lineLimit(1)
                                .frame(width: 56)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(lang.l("group.name_label"))
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundColor(AppTheme.Colors.secondary)
                TextField(lang.l("group.name_placeholder"), text: $groupName)
                    .textFieldStyle(DarkTextFieldStyle())
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            GradientButton(
                title: lang.l("group.create"),
                icon: "person.3.fill",
                isLoading: isCreating
            ) {
                createGroup()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
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

    private func createGroup() {
        guard let uid = authVM.user?.uid, !isCreating else { return }
        isCreating = true
        Task {
            do {
                var imageURL: String?
                if let groupImageData {
                    isUploadingPhoto = true
                    // Upload with a temporary ID first, then use returned chatId
                    let tempId = UUID().uuidString
                    imageURL = try await StorageService.shared.uploadGroupImage(
                        chatId: tempId,
                        imageData: groupImageData
                    )
                    await MainActor.run { isUploadingPhoto = false }
                }

                let chatId = try await ChatService.shared.createGroupChat(
                    creatorUid: uid,
                    memberUids: Array(selectedUids),
                    groupName: groupName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : groupName.trimmingCharacters(in: .whitespaces),
                    groupImageURL: imageURL
                )
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    onCreated(chatId)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    isUploadingPhoto = false
                }
                print("Create group error: \(error)")
            }
        }
    }
}

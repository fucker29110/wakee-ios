import SwiftUI
import PhotosUI

struct GroupSettingsSheet: View {
    let chatId: String
    let chat: Chat
    let participantMap: [String: (displayName: String, photoURL: String?)]

    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss

    @State private var editingName = false
    @State private var newGroupName = ""
    @State private var showAddMembers = false
    @State private var removeMemberUid: String?
    @State private var showRemoveAlert = false
    @State private var showLeaveAlert = false
    @State private var isUpdating = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var previewImageData: Data?

    private var isAdmin: Bool {
        authVM.user?.uid == chat.createdBy
    }

    var body: some View {
        NavigationStack {
            List {
                // Group Image Section
                Section {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        if let previewImageData, let uiImage = UIImage(data: previewImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let url = chat.groupImageURL, !url.isEmpty {
                            AvatarView(name: chat.groupName ?? "Group", photoURL: url, size: 80)
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                } header: {
                    Text(lang.l("group.photo"))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .listRowBackground(AppTheme.Colors.surface)

                // Group Name Section
                Section {
                    HStack {
                        if editingName {
                            TextField(lang.l("group.name_placeholder"), text: $newGroupName)
                                .foregroundColor(AppTheme.Colors.primary)
                            Button(lang.l("common.save")) {
                                saveGroupName()
                            }
                            .foregroundColor(AppTheme.Colors.accent)
                            .disabled(isUpdating)
                        } else {
                            Text(chat.groupName ?? lang.l("group.default_name"))
                                .foregroundColor(AppTheme.Colors.primary)
                            Spacer()
                            if isAdmin {
                                Button {
                                    newGroupName = chat.groupName ?? ""
                                    editingName = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text(lang.l("group.set_name"))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .listRowBackground(AppTheme.Colors.surface)

                // Members Section
                Section {
                    ForEach(chat.users, id: \.self) { uid in
                        let info = participantMap[uid]
                        let name = info?.displayName ?? uid
                        let isMe = uid == authVM.user?.uid
                        HStack(spacing: AppTheme.Spacing.sm) {
                            if isMe {
                                memberContent(uid: uid, name: name, photoURL: info?.photoURL)
                            } else {
                                NavigationLink {
                                    FriendProfileScreen(uid: uid)
                                } label: {
                                    memberContent(uid: uid, name: name, photoURL: info?.photoURL)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            if isAdmin && !isMe {
                                Button {
                                    removeMemberUid = uid
                                    showRemoveAlert = true
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(AppTheme.Colors.danger)
                                }
                            }
                        }
                    }

                    if isAdmin {
                        Button {
                            showAddMembers = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(AppTheme.Colors.accent)
                                Text(lang.l("group.add_members"))
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
                } header: {
                    Text(lang.l("group.member_count", args: chat.users.count))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .listRowBackground(AppTheme.Colors.surface)

                // Leave Group
                if !isAdmin {
                    Section {
                        Button {
                            showLeaveAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text(lang.l("group.leave"))
                            }
                            .foregroundColor(AppTheme.Colors.danger)
                        }
                    }
                    .listRowBackground(AppTheme.Colors.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle(lang.l("group.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.l("common.done")) { dismiss() }
                        .foregroundColor(AppTheme.Colors.accent)
                        .disabled(isUploadingPhoto)
                }
            }
            .sheet(isPresented: $showAddMembers) {
                AddGroupMembersSheet(chatId: chatId, existingMemberUids: Set(chat.users))
            }
            .alert(lang.l("group.remove_title"), isPresented: $showRemoveAlert) {
                Button(lang.l("group.remove"), role: .destructive) {
                    if let uid = removeMemberUid {
                        removeMember(uid: uid)
                    }
                }
                Button(lang.l("common.cancel"), role: .cancel) {}
            } message: {
                let name = participantMap[removeMemberUid ?? ""]?.displayName ?? ""
                Text(lang.l("group.remove_confirm", args: name))
            }
            .alert(lang.l("group.leave_title"), isPresented: $showLeaveAlert) {
                Button(lang.l("group.leave"), role: .destructive) {
                    leaveGroup()
                }
                Button(lang.l("common.cancel"), role: .cancel) {}
            } message: {
                Text(lang.l("group.leave_confirm"))
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
                            uploadCroppedImage(croppedImage)
                        },
                        onCancel: {
                            cropImage = nil
                        }
                    )
                }
            }
        }
    }

    private func memberContent(uid: String, name: String, photoURL: String?) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: name, photoURL: photoURL, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundColor(AppTheme.Colors.primary)
                if uid == chat.createdBy {
                    Text(lang.l("group.admin"))
                        .font(.system(size: AppTheme.FontSize.xs))
                        .foregroundColor(AppTheme.Colors.accent)
                }
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
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        previewImageData = data
        isUploadingPhoto = true
        Task {
            do {
                let url = try await StorageService.shared.uploadGroupImage(
                    chatId: chatId,
                    imageData: data
                )
                try await ChatService.shared.updateGroupImage(chatId: chatId, imageURL: url)
                await MainActor.run {
                    isUploadingPhoto = false
                }
            } catch {
                await MainActor.run { isUploadingPhoto = false }
                print("Upload group image error: \(error)")
            }
        }
    }

    private func saveGroupName() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        isUpdating = true
        Task {
            try? await ChatService.shared.updateGroupName(chatId: chatId, newName: trimmed)
            await MainActor.run {
                isUpdating = false
                editingName = false
            }
        }
    }

    private func removeMember(uid: String) {
        Task {
            try? await ChatService.shared.removeMemberFromGroup(chatId: chatId, uid: uid)
        }
    }

    private func leaveGroup() {
        guard let uid = authVM.user?.uid else { return }
        Task {
            try? await ChatService.shared.removeMemberFromGroup(chatId: chatId, uid: uid)
            await MainActor.run { dismiss() }
        }
    }
}

import SwiftUI

struct AddGroupMembersSheet: View {
    let chatId: String
    let existingMemberUids: Set<String>

    @Environment(FriendsViewModel.self) private var friendsVM
    @Environment(LanguageManager.self) private var lang
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUids: Set<String> = []
    @State private var searchText = ""
    @State private var isAdding = false

    private var availableFriends: [AppUser] {
        let friends = friendsVM.friends.filter { !existingMemberUids.contains($0.uid) }
        if searchText.isEmpty { return friends }
        let query = searchText.lowercased()
        return friends.filter {
            $0.displayName.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
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

                if availableFriends.isEmpty {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.Colors.secondary)
                        Text(lang.l("group.no_friends_to_add"))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(availableFriends) { friend in
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
            .background(AppTheme.Colors.background)
            .navigationTitle(lang.l("group.add_members"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.l("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.l("group.add")) {
                        addMembers()
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                    .disabled(selectedUids.isEmpty || isAdding)
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

    private func addMembers() {
        isAdding = true
        Task {
            for uid in selectedUids {
                try? await ChatService.shared.addMemberToGroup(chatId: chatId, uid: uid)
            }
            await MainActor.run {
                isAdding = false
                dismiss()
            }
        }
    }
}

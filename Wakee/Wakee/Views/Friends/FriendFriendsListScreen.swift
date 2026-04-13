import SwiftUI
import FirebaseFirestore

struct FriendFriendsListScreen: View {
    let uid: String
    let displayName: String

    @Environment(LanguageManager.self) private var lang
    @State private var friends: [AppUser] = []
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friends.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.secondary)
                    Text(lang.l("friends.no_friends"))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(friends) { friend in
                            NavigationLink {
                                FriendProfileScreen(uid: friend.uid)
                            } label: {
                                friendRow(friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(lang.l("friend.friends_of", args: displayName))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            listener = FriendService.shared.subscribeFriends(uid: uid) { friends in
                self.friends = friends
                self.isLoading = false
            }
        }
        .onDisappear {
            listener?.remove()
        }
    }

    private func friendRow(_ friend: AppUser) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: friend.displayName, photoURL: friend.photoURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                Text("@\(friend.username)")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().fill(Color(hex: "#1F1F1F")).frame(height: 1),
            alignment: .bottom
        )
    }
}

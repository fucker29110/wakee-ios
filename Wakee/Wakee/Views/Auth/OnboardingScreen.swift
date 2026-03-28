import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UserNotifications

private let onboardingTotalSteps = 4

struct OnboardingScreen: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var step = 0

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            switch step {
            case 0:
                OnboardingNameStep(onNext: { step = 1 })
                    .environment(authVM)
            case 1:
                OnboardingUsernameStep(onNext: { step = 2 })
                    .environment(authVM)
            case 2:
                OnboardingFriendsStep(onComplete: { step = 3 })
                    .environment(authVM)
            default:
                OnboardingPermissionsStep(onComplete: { completeOnboarding() })
            }
        }
    }

    private func completeOnboarding() {
        guard let uid = authVM.user?.uid else { return }
        Task {
            try? await AuthService.shared.completeOnboarding(uid: uid)
            await MainActor.run { authVM.needsOnboarding = false }
        }
    }
}

// MARK: - Step 1: Name & Avatar

struct OnboardingNameStep: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var name = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var isUploading = false
    @State private var cropImage: UIImage?
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer().frame(height: 40)
            stepHeader
            Spacer().frame(height: 20)
            avatarPicker
            nameField
            Spacer()
            continueButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.xl)
        .onAppear { name = authVM.user?.displayName ?? "" }
    }

    private var stepHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(lang.l("onboarding.create_account"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
            stepIndicator(current: 0)
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            if let avatarData, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(cameraOverlay)
            } else {
                AvatarView(name: name, photoURL: authVM.user?.photoURL, size: 100)
                    .overlay(cameraOverlay)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { cropImage = uiImage }
                }
            }
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
                        if let jpegData = croppedImage.jpegData(compressionQuality: 0.85) {
                            avatarData = jpegData
                        }
                    },
                    onCancel: {
                        cropImage = nil
                    }
                )
            }
        }
    }

    private var cameraOverlay: some View {
        Circle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
            .offset(x: 35, y: 35)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(lang.l("onboarding.name"))
                .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                .foregroundColor(AppTheme.Colors.secondary)
            TextField(lang.l("onboarding.enter_name"), text: $name)
                .textFieldStyle(DarkTextFieldStyle())
        }
    }

    private var continueButton: some View {
        Button {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            isUploading = true
            Task {
                // Upload avatar if selected
                if let avatarData, let uid = authVM.user?.uid {
                    if let url = try? await StorageService.shared.uploadProfileImage(uid: uid, imageData: avatarData) {
                        await authVM.updateProfile(params: ["displayName": name, "photoURL": url])
                    } else {
                        await authVM.updateProfile(params: ["displayName": name])
                    }
                } else {
                    await authVM.updateProfile(params: ["displayName": name])
                }
                await MainActor.run {
                    isUploading = false
                    onNext()
                }
            }
        } label: {
            Group {
                if isUploading {
                    ProgressView().tint(.white)
                } else {
                    Text(lang.l("common.continue"))
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                    .fill(canContinueName ? AppTheme.accentGradient : LinearGradient(colors: [AppTheme.Colors.surfaceVariant], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(!canContinueName || isUploading)
    }

    private var canContinueName: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Step 2: Username

struct OnboardingUsernameStep: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var username = ""
    @State private var isAvailable: Bool?
    @State private var isChecking = false
    @State private var isSaving = false
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer().frame(height: 40)
            usernameHeader
            Spacer().frame(height: 20)
            usernameField
            Spacer()
            continueButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.xl)
        .onAppear { username = "" }
    }

    private var usernameHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(lang.l("onboarding.create_account"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
            stepIndicator(current: 1)
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(lang.l("onboarding.username"))
                .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                .foregroundColor(AppTheme.Colors.secondary)
            Text(lang.l("onboarding.username_hint"))
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)

            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("username", text: $username)
                    .textFieldStyle(DarkTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, _ in
                        isAvailable = nil
                        checkUsername()
                    }

                Button { generateRandom() } label: {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.accent)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.Colors.surfaceVariant)
                        .cornerRadius(AppTheme.BorderRadius.sm)
                }
            }

            availabilityLabel
        }
    }

    @ViewBuilder
    private var availabilityLabel: some View {
        if isChecking {
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7).tint(AppTheme.Colors.secondary)
                Text(lang.l("onboarding.checking"))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        } else if let isAvailable {
            HStack(spacing: 4) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isAvailable ? AppTheme.Colors.success : AppTheme.Colors.danger)
                Text(isAvailable ? lang.l("onboarding.available") : lang.l("onboarding.already_taken"))
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(isAvailable ? AppTheme.Colors.success : AppTheme.Colors.danger)
            }
        }
    }

    private var continueButton: some View {
        Button {
            isSaving = true
            Task {
                await authVM.updateProfile(params: ["username": username])
                await MainActor.run {
                    isSaving = false
                    onNext()
                }
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(lang.l("common.continue"))
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                    .fill(canContinue ? AppTheme.accentGradient : LinearGradient(colors: [AppTheme.Colors.surfaceVariant], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(!canContinue || isSaving)
    }

    private var canContinue: Bool {
        isValidUsername && isAvailable == true
    }

    private var isValidUsername: Bool {
        let pattern = "^[a-zA-Z0-9._]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }

    private func checkUsername() {
        let current = username
        guard isValidUsername else { isAvailable = nil; return }
        isChecking = true
        Task {
            guard let uid = authVM.user?.uid else { return }
            let available = try? await AuthService.shared.isUsernameAvailable(username: current, myUid: uid)
            await MainActor.run {
                guard username == current else { return }
                isAvailable = available ?? false
                isChecking = false
            }
        }
    }

    private func generateRandom() {
        let name = authVM.user?.displayName ?? "user"
        let base = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let prefix = base.isEmpty ? "user" : String(base.prefix(12))
        let charset = "abcdefghijklmnopqrstuvwxyz0123456789"
        let suffix = String((0..<4).map { _ in charset.randomElement() ?? "0" })
        username = "\(prefix)_\(suffix)"
    }
}

// MARK: - Step 3: Find Friends

struct OnboardingFriendsStep: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(LanguageManager.self) private var lang
    @State private var friendsVM = FriendsViewModel()
    @State private var copiedLink = false
    var onComplete: () -> Void

    private var profileLink: String {
        "https://apps.apple.com/jp/app/wakee/id6760428796?l=en-US"
    }

    var body: some View {
        VStack(spacing: 0) {
            friendsHeader
            shareBanner
            searchBar
            suggestionsList
            Spacer()
            bottomButtons
        }
        .padding(.bottom, AppTheme.Spacing.xl)
        .onAppear {
            guard let uid = authVM.user?.uid else { return }
            friendsVM.subscribe(uid: uid)
            Task { await friendsVM.fetchSuggestions(uid: uid) }
        }
        .onDisappear { friendsVM.unsubscribe() }
    }

    private var friendsHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Spacer().frame(height: 40)
            Text(lang.l("onboarding.find_friends"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
            stepIndicator(current: 2)
            Spacer().frame(height: 10)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    private var shareBanner: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "link")
                    .foregroundColor(AppTheme.Colors.accent)
                Text(lang.l("onboarding.share_invite"))
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }

            Text(profileLink)
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)

            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    UIPasteboard.general.string = profileLink
                    copiedLink = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await MainActor.run { copiedLink = false }
                    }
                } label: {
                    Label(copiedLink ? lang.l("onboarding.copied") : lang.l("onboarding.copy"), systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(copiedLink ? AppTheme.Colors.success : AppTheme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().stroke(AppTheme.Colors.border, lineWidth: 1))
                }

                Button {
                    let activityVC = UIActivityViewController(
                        activityItems: ["\(lang.l("onboarding.invite_message")) \(profileLink)"],
                        applicationActivities: nil
                    )
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = windowScene.windows.first?.rootViewController {
                        root.present(activityVC, animated: true)
                    }
                } label: {
                    Label(lang.l("onboarding.share"), systemImage: "square.and.arrow.up")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField(lang.l("onboarding.search_by_username"), text: Binding(
                get: { friendsVM.searchQuery },
                set: { friendsVM.searchQuery = $0.replacingOccurrences(of: "@", with: "") }
            ))
            .textFieldStyle(DarkTextFieldStyle())
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit {
                guard let uid = authVM.user?.uid else { return }
                Task { await friendsVM.search(myUid: uid) }
            }

            Button {
                guard let uid = authVM.user?.uid else { return }
                Task { await friendsVM.search(myUid: uid) }
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.BorderRadius.sm)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .onAppear { friendsVM.searchUid = authVM.user?.uid }
    }

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Search results
                if !friendsVM.searchResults.isEmpty {
                    sectionHeader(lang.l("onboarding.search_results"))
                    ForEach(friendsVM.searchResults) { user in
                        userRow(user)
                    }
                }

                // Suggestions
                if !friendsVM.suggestions.isEmpty {
                    sectionHeader(lang.l("onboarding.suggestions"))
                    ForEach(friendsVM.suggestions) { suggestion in
                        userRow(suggestion.user, subtitle: lang.l("onboarding.mutual_friends", args: suggestion.mutualCount))
                    }
                }

                if friendsVM.isLoadingSuggestions {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .padding(.vertical, AppTheme.Spacing.xl)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
            .foregroundColor(AppTheme.Colors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xs)
    }

    private func userRow(_ user: AppUser, subtitle: String? = nil) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            AvatarView(name: user.displayName, photoURL: user.photoURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                Text(subtitle ?? "@\(user.username)")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
            addButton(user)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func addButton(_ user: AppUser) -> some View {
        if friendsVM.sentRequests.contains(user.uid) {
            Text(lang.l("onboarding.request_sent"))
                .font(.system(size: AppTheme.FontSize.xs))
                .foregroundColor(AppTheme.Colors.secondary)
        } else {
            Button {
                guard let me = authVM.user else { return }
                Task { await friendsVM.sendRequest(fromUid: me.uid, toUid: user.uid, fromName: me.displayName, fromUsername: me.username) }
            } label: {
                Text(lang.l("onboarding.add"))
                    .font(.system(size: AppTheme.FontSize.sm, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.Colors.accent))
            }
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button {
                onComplete()
            } label: {
                Text(lang.l("common.continue"))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                            .fill(AppTheme.accentGradient)
                    )
            }

            Button(lang.l("common.skip")) { onComplete() }
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

// MARK: - Step Indicator

private func stepIndicator(current: Int) -> some View {
    HStack(spacing: AppTheme.Spacing.sm) {
        ForEach(0..<onboardingTotalSteps, id: \.self) { i in
            RoundedRectangle(cornerRadius: 2)
                .fill(i <= current ? AppTheme.Colors.accent : AppTheme.Colors.surfaceVariant)
                .frame(height: 4)
        }
    }
    .frame(width: 160)
}

// MARK: - Step 4: Permissions

struct OnboardingPermissionsStep: View {
    @State private var isRequesting = false
    @Environment(LanguageManager.self) private var lang
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer().frame(height: 40)
            permissionsHeader
            Spacer().frame(height: 10)
            permissionsList
            Spacer()
            continueButton
            footerText
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.xl)
    }

    private var permissionsHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(lang.l("onboarding.grant_permissions"))
                .font(.system(size: AppTheme.FontSize.xl, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
            stepIndicator(current: 3)
        }
    }

    private var permissionsList: some View {
        VStack(spacing: 0) {
            permissionRow(
                icon: "bell.fill",
                title: lang.l("onboarding.notification"),
                description: lang.l("onboarding.notification_desc")
            )
            permissionRow(
                icon: "camera.fill",
                title: lang.l("onboarding.camera"),
                description: lang.l("onboarding.camera_desc")
            )
            permissionRow(
                icon: "mic.fill",
                title: lang.l("onboarding.microphone"),
                description: lang.l("onboarding.mic_desc")
            )
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.BorderRadius.md)
    }

    private func permissionRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: AppTheme.FontSize.md, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text(description)
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, 14)
    }

    private var continueButton: some View {
        Button {
            isRequesting = true
            Task {
                await requestAllPermissions()
                await MainActor.run {
                    isRequesting = false
                    onComplete()
                }
            }
        } label: {
            Group {
                if isRequesting {
                    ProgressView().tint(.white)
                } else {
                    Text(lang.l("common.continue"))
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.md)
                    .fill(AppTheme.accentGradient)
            )
        }
        .disabled(isRequesting)
    }

    private var footerText: some View {
        Text(lang.l("onboarding.settings_changeable"))
            .font(.system(size: AppTheme.FontSize.xs))
            .foregroundColor(AppTheme.Colors.secondary)
    }

    private func requestAllPermissions() async {
        // Notifications
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])

        try? await Task.sleep(for: .milliseconds(500))

        // Camera
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                continuation.resume()
            }
        }

        try? await Task.sleep(for: .milliseconds(500))

        // Microphone
        if #available(iOS 17.0, *) {
            _ = try? await AVAudioApplication.requestRecordPermission()
        } else {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        }
    }
}

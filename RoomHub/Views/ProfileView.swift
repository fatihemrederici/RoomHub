import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @ObservedObject var rateService = ExchangeRateService.shared
    
    @AppStorage("profileDisplayCurrency") var displayCurrencyCode: String = Currency.deviceDefaultCode
    @State var showCurrencyPicker = false
    
    @State var showPhotoActionSheet = false
    @State var showEditName = false
    @State var editedName = ""
    @State var showPhotosPicker = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isUploadingPhoto = false
    
    @State var showChangePassword = false
    @State var showPrivacy = false
    @State var showLogoutConfirmation = false
    @State var showDeleteConfirmation = false
    @State var deletePassword = ""
    @State var isDeletingAccount = false
    
    var me: String { store.currentUserId }
    var user: AppUser? { authVM.currentUser }
    var displayCurrency: Currency { Currency.find(displayCurrencyCode) }
    
    var expensesLoggedCount: Int { store.expenses.filter { $0.paidBy == me }.count }
    var choresCompletedCount: Int { store.chores.filter { $0.completed && $0.completedBy == me }.count }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        heroProfileCard
                        activityStatsGrid
                        preferencesSection
                        accountSection
                        Text("RoomHub \(appVersion)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .alert("Edit Name", isPresented: $showEditName) {
                TextField("Your name", text: $editedName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveName() }
            } message: {
                Text("This name is visible to your roommates.")
            }
            .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) { authVM.logout() }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                SecureField("Password", text: $deletePassword)
                Button("Cancel", role: .cancel) { deletePassword = "" }
                Button("Delete", role: .destructive) { deleteAccount() }
            } message: {
                Text("This permanently deletes your account and removes you from your house. Shared expenses you were part of stay in your roommates' history under your name. Enter your password to confirm.")
            }
            .sheet(isPresented: $showPhotoActionSheet) {
                PhotoActionSheet(
                    hasPhoto: user?.photoBase64 != nil,
                    onChoosePhoto: {
                        showPhotoActionSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showPhotosPicker = true }
                    },
                    onRemovePhoto: {
                        showPhotoActionSheet = false
                        removePhoto()
                    }
                )
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: Binding(
                    get: { displayCurrency },
                    set: { displayCurrencyCode = $0.code }
                ))
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView().environmentObject(authVM)
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await uploadPhoto(newItem) }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Hero Profile Card
    var heroProfileCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(AppTheme.heroGradient)
                .overlay(
                    Circle()
                        .fill(AppTheme.mint.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: 100, y: -80)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            
            VStack(spacing: 14) {
                ZStack {
                    if let image = ImageProcessor.image(fromBase64: user?.photoBase64) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 92)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5))
                    } else {
                        Circle()
                            .fill(AppTheme.mintGradient)
                            .frame(width: 92, height: 92)
                        Text(user?.initial ?? "U")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if isUploadingPhoto {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 92, height: 92)
                        ProgressView().tint(.white)
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showPhotoActionSheet = true }) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.mint)
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().stroke(AppTheme.background, lineWidth: 3))
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .accessibilityLabel("Change profile photo")
                        }
                    }
                    .frame(width: 92, height: 92)
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(user?.name ?? "...")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        Button(action: {
                            editedName = user?.name ?? ""
                            showEditName = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .accessibilityLabel("Edit name")
                    }
                    Text(user?.email ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                    if let joined = user?.createdAt {
                        Text("Member since \(joined.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 28)
        }
    }
    
    // MARK: - Activity Stats Grid
    var activityStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("ACTIVITY IN \((store.house?.houseName ?? "HOUSE").uppercased())")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ProfileStatCard(
                    title: "Total Paid (all time)",
                    icon: "creditcard.fill",
                    value: store.isLoadingExpenses ? "···" : displayCurrency.format(store.display(store.totalPaidByMe, in: displayCurrency)),
                    color: AppTheme.mint
                )
                ProfileStatCard(
                    title: "Balance",
                    icon: "chart.line.uptrend.xyaxis",
                    value: store.isLoadingExpenses ? "···" : displayCurrency.formatSigned(store.display(store.myBalance, in: displayCurrency)),
                    color: store.myBalance >= 0 ? AppTheme.mint : AppTheme.coral
                )
                ProfileStatCard(
                    title: "Expenses Paid",
                    icon: "list.bullet.rectangle.fill",
                    value: "\(expensesLoggedCount)",
                    color: AppTheme.violet
                )
                ProfileStatCard(
                    title: "Chores Done",
                    icon: "checkmark.circle.fill",
                    value: "\(choresCompletedCount)",
                    color: AppTheme.amber
                )
            }
        }
    }
    
    // MARK: - Preferences
    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("PREFERENCES")
            VStack(spacing: 0) {
                Button(action: { showCurrencyPicker = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(AppTheme.mint.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text(displayCurrency.flag).font(.system(size: 15))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Display Currency")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Used for totals on your screens")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                        Text(displayCurrency.code)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .glassCard()
        }
    }
    
    // MARK: - Account
    var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel("ACCOUNT")
            VStack(spacing: 0) {
                SettingsRow(icon: "key.fill", iconColor: AppTheme.violet, title: "Change Password") {
                    showChangePassword = true
                }
                divider
                SettingsRow(icon: "hand.raised.fill", iconColor: AppTheme.mint, title: "Privacy Policy") {
                    showPrivacy = true
                }
                divider
                SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: AppTheme.coral,
                            title: "Log Out", textColor: AppTheme.coral, showChevron: false) {
                    showLogoutConfirmation = true
                }
                divider
                SettingsRow(icon: "trash.fill", iconColor: AppTheme.coral,
                            title: isDeletingAccount ? "Deleting..." : "Delete Account",
                            textColor: AppTheme.coral, showChevron: false, isLoading: isDeletingAccount) {
                    showDeleteConfirmation = true
                }
            }
            .glassCard()
        }
    }
    
    var divider: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.leading, 62)
    }
    
    // MARK: - Actions
    func deleteAccount() {
        let password = deletePassword
        deletePassword = ""
        guard !password.isEmpty else {
            ToastManager.shared.show("Enter your password to delete your account", type: .error)
            return
        }
        isDeletingAccount = true
        // Önce şifreyle doğrula; böylece "yeniden giriş gerekli" hatası evden ayrıldıktan sonra gelmez
        authVM.reauthenticate(password: password) { success, error in
            guard success else {
                isDeletingAccount = false
                ToastManager.shared.show(error ?? "Incorrect password", type: .error)
                return
            }
            authVM.stopListening()
            store.leaveHouse { _, _ in
                authVM.deleteAccount { success, error in
                    isDeletingAccount = false
                    if success {
                        ToastManager.shared.show("Your account was deleted", type: .success)
                    } else {
                        ToastManager.shared.show(error ?? "Failed to delete account", type: .error)
                    }
                }
            }
        }
    }
    
    func saveName() {
        let newName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName.count <= 50 else {
            ToastManager.shared.show("Name must be 1–50 characters", type: .error)
            return
        }
        authVM.updateName(newName) { success, error in
            ToastManager.shared.show(success ? "Name updated" : (error ?? "Failed to update name"),
                                     type: success ? .success : .error)
        }
    }
    
    func uploadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        isUploadingPhoto = true
        defer { selectedPhotoItem = nil }
        
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let jpeg = ImageProcessor.squareJPEG(from: uiImage) else {
            isUploadingPhoto = false
            ToastManager.shared.show("Couldn't load the selected photo", type: .error)
            return
        }
        
        authVM.updatePhoto(imageData: jpeg) { success, error in
            isUploadingPhoto = false
            ToastManager.shared.show(success ? "Photo updated" : (error ?? "Failed to update photo"),
                                     type: success ? .success : .error)
        }
    }
    
    func removePhoto() {
        authVM.removePhoto { success, error in
            ToastManager.shared.show(success ? "Photo removed" : (error ?? "Failed to remove photo"),
                                     type: success ? .success : .error)
        }
    }
}

// MARK: - Stat Card
struct ProfileStatCard: View {
    let title: String
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var textColor: Color = AppTheme.textPrimary
    var showChevron: Bool = true
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textColor)
                Spacer()
                if isLoading {
                    ProgressView().tint(AppTheme.textMuted)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .disabled(isLoading)
    }
}

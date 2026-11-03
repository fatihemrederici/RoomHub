import SwiftUI
import PhotosUI

struct HouseManagementView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @Environment(\.dismiss) var dismiss
    
    @State var showEditName = false
    @State var editedName = ""
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isUploadingImage = false
    @State var showCurrencyPicker = false
    @State var pendingCurrency: Currency?
    @State var showRegenerateConfirmation = false
    @State var memberPendingRemoval: AppUser?
    @State var memberPendingOwnership: AppUser?
    @State var showLeaveConfirmation = false
    @State var isLeaving = false
    @State var showCopied = false
    
    var house: House? { store.house }
    var me: String { store.currentUserId }
    
   
    var body: some View {
        NavigationStack {
            screenWithDialogs
                .sheet(isPresented: $showCurrencyPicker) {
                    CurrencyPickerView(selectedCurrency: currencyPickerBinding)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await uploadImage(newItem) }
                }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Screen parts
    var mainContent: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if store.isLoadingHouse && house == nil {
                ProgressView().tint(AppTheme.mint)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        houseImageSection
                        inviteCodeCard
                        currencyCard
                        membersSection
                        leaveHouseButton
                    }
                    .padding(20)
                }
            }
            
            if showCopied {
                copiedToast
            }
        }
    }
    
    var copiedToast: some View {
        VStack {
            Spacer()
            Text("Code copied!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.mint)
                .cornerRadius(20)
                .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    var screenWithToolbar: some View {
        mainContent
            .navigationTitle("House")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
    }
    
    var screenWithAlerts: some View {
        screenWithToolbar
            .alert("Rename House", isPresented: $showEditName) {
                TextField("House name", text: $editedName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { renameHouse() }
            } message: {
                Text("Up to 40 characters.")
            }
            .alert("Generate a new invite code?", isPresented: $showRegenerateConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Generate") { regenerateCode() }
            } message: {
                Text("The current code will stop working. Current members are not affected.")
            }
            .alert("Leave House?", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) { leaveHouse() }
            } message: {
                Text(leaveMessage)
            }
    }
    
    var screenWithCurrencyAlert: some View {
        screenWithAlerts
            .alert("Change house currency?", isPresented: showCurrencyAlertBinding, presenting: pendingCurrency) { (currency: Currency) in
                Button("Cancel", role: .cancel) {}
                Button("Change to \(currency.code)") { changeCurrency(currency) }
            } message: { (_: Currency) in
                Text("Balances will be shown in the new currency. Expenses in other currencies are converted at today's rate.")
            }
    }
    
    var screenWithDialogs: some View {
        screenWithCurrencyAlert
            .confirmationDialog("Remove member?", isPresented: showRemoveBinding,
                                titleVisibility: .visible, presenting: memberPendingRemoval) { (member: AppUser) in
                Button("Remove \(member.name)", role: .destructive) { removeMember(member) }
                Button("Cancel", role: .cancel) {}
            } message: { (member: AppUser) in
                Text(removalMessage(for: member))
            }
            .confirmationDialog("Transfer ownership?", isPresented: showTransferBinding,
                                titleVisibility: .visible, presenting: memberPendingOwnership) { (member: AppUser) in
                Button("Make \(member.name) the owner") { transferOwnership(to: member) }
                Button("Cancel", role: .cancel) {}
            } message: { (_: AppUser) in
                Text("You'll stay in the house as an admin.")
            }
    }
    
    // MARK: - Bindings
    var showCurrencyAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { pendingCurrency != nil },
            set: { isShown in if !isShown { pendingCurrency = nil } }
        )
    }
    
    var showRemoveBinding: Binding<Bool> {
        Binding<Bool>(
            get: { memberPendingRemoval != nil },
            set: { isShown in if !isShown { memberPendingRemoval = nil } }
        )
    }
    
    var showTransferBinding: Binding<Bool> {
        Binding<Bool>(
            get: { memberPendingOwnership != nil },
            set: { isShown in if !isShown { memberPendingOwnership = nil } }
        )
    }
    
    var currencyPickerBinding: Binding<Currency> {
        Binding<Currency>(
            get: { store.baseCurrency },
            set: { newValue in
                guard newValue.code != store.baseCurrencyCode else { return }
                // Seçici kapandıktan sonra onay penceresini göster
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    pendingCurrency = newValue
                }
            }
        )
    }
    
    // MARK: - House Image & Name
    var houseImageSection: some View {
        VStack(spacing: 10) {
            ZStack {
                if let image = ImageProcessor.image(fromBase64: house?.imageBase64) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.violetGradient)
                        .frame(width: 90, height: 90)
                    Image(systemName: "house.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                if isUploadingImage {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 90, height: 90)
                    ProgressView().tint(.white)
                }
                
                if store.isAdmin {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Menu {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label("Choose Photo", systemImage: "photo")
                                }
                                if house?.imageBase64 != nil {
                                    Button(role: .destructive, action: removeImage) {
                                        Label("Remove Photo", systemImage: "trash")
                                    }
                                }
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(AppTheme.mint)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Change house photo")
                        }
                    }
                    .frame(width: 90, height: 90)
                }
            }
            
            HStack(spacing: 6) {
                Text(house?.houseName ?? "")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                if store.isAdmin {
                    Button(action: {
                        editedName = house?.houseName ?? ""
                        showEditName = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(6)
                    }
                    .accessibilityLabel("Rename house")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
    
    // MARK: - Invite Code
    var inviteCodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Invite Code")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                    Text(house?.inviteCode ?? "")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.mint)
                        .textSelection(.enabled)
                }
                Spacer()
                if store.isAdmin {
                    Button(action: { showRegenerateConfirmation = true }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Generate new invite code")
                }
            }
            
            HStack(spacing: 10) {
                Button(action: copyCode) {
                    Label("Copy", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.mintGradient)
                        .cornerRadius(12)
                }
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.violetGradient)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .glassCard()
    }
    
    var shareText: String {
        "Join my house \"\(house?.houseName ?? "")\" on RoomHub! Open the app, tap \"Join a House\" and enter code: \(house?.inviteCode ?? "")"
    }
    
    // MARK: - Currency
    var currencyCard: some View {
        Button(action: { if store.isAdmin { showCurrencyPicker = true } }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AppTheme.amber.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Text(store.baseCurrency.flag).font(.system(size: 15))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("House Currency")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Balances are calculated in this currency")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Text(store.baseCurrencyCode)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                if store.isAdmin {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassCard()
        }
        .disabled(!store.isAdmin)
    }
    
    // MARK: - Members
    var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(store.memberIds.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            VStack(spacing: 10) {
                ForEach(store.memberList) { member in
                    let uid = member.id ?? ""
                    MemberRow(
                        member: member,
                        isAdmin: house?.isAdmin(uid) ?? false,
                        isCreator: house?.createdBy == uid,
                        canManage: store.isAdmin && house?.createdBy != uid && uid != me,
                        canTransfer: store.isOwner && uid != me,
                        isSelf: uid == me,
                        balanceText: balanceText(for: uid),
                        onToggleAdmin: { toggleAdmin(member) },
                        onMakeOwner: { memberPendingOwnership = member },
                        onRemove: { memberPendingRemoval = member }
                    )
                }
            }
        }
    }
    
    func balanceText(for uid: String) -> String? {
        let balance = store.balance(of: uid)
        guard balance != 0 else { return nil }
        let currency = store.baseCurrency
        return balance > 0 ? "is owed \(currency.format(balance))" : "owes \(currency.format(-balance))"
    }
    
    var leaveHouseButton: some View {
        Button(action: { showLeaveConfirmation = true }) {
            HStack {
                if isLeaving {
                    ProgressView().tint(AppTheme.coral)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Leave House")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppTheme.coral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.coral.opacity(0.1))
            .cornerRadius(14)
        }
        .disabled(isLeaving)
    }
    
    var leaveMessage: String {
        var parts: [String] = []
        let balance = store.myBalance
        if balance != 0 {
            let amount = store.baseCurrency.format(abs(balance))
            parts.append(balance > 0
                         ? "You're still owed \(amount). Settle up before leaving."
                         : "You still owe \(amount). Settle up before leaving.")
        }
        if store.isOwner && store.memberIds.count > 1 {
            parts.append("Ownership will transfer to another member.")
        } else if store.memberIds.count <= 1 {
            parts.append("You're the only member. Leaving will permanently delete this house and all its data.")
        } else {
            parts.append("You'll need an invite code to rejoin.")
        }
        return parts.joined(separator: "\n\n")
    }
    
    func removalMessage(for member: AppUser) -> String {
        var text = "\(member.name) will lose access to this house. A new invite code will be generated."
        if let uid = member.id, store.balance(of: uid) != 0 {
            text += "\n\nThey still have an open balance; it will stay in the history under their name."
        }
        return text
    }
    
    // MARK: - Actions
    func copyCode() {
        guard let code = house?.inviteCode else { return }
        UIPasteboard.general.string = code
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
    
    func renameHouse() {
        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else {
            ToastManager.shared.show("House name must be 1–40 characters", type: .error)
            return
        }
        store.renameHouse(name) { success, error in
            ToastManager.shared.show(success ? "House renamed" : (error ?? "Failed to rename house"),
                                     type: success ? .success : .error)
        }
    }
    
    func regenerateCode() {
        store.regenerateInviteCode { success, error in
            ToastManager.shared.show(success ? "New invite code ready" : (error ?? "Couldn't generate a new code"),
                                     type: success ? .success : .error)
        }
    }
    
    func changeCurrency(_ currency: Currency) {
        store.setBaseCurrency(currency) { success, error in
            ToastManager.shared.show(success ? "House currency set to \(currency.code)" : (error ?? "Failed to change currency"),
                                     type: success ? .success : .error)
        }
    }
    
    func toggleAdmin(_ member: AppUser) {
        guard let uid = member.id else { return }
        let currentlyAdmin = house?.adminList.contains(uid) ?? false
        store.setAdmin(uid, isAdmin: !currentlyAdmin) { success, error in
            ToastManager.shared.show(success ? (currentlyAdmin ? "Admin removed" : "Admin added") : (error ?? "Failed to update admin"),
                                     type: success ? .success : .error)
        }
    }
    
    func transferOwnership(to member: AppUser) {
        guard let uid = member.id else { return }
        store.transferOwnership(to: uid) { success, error in
            ToastManager.shared.show(success ? "\(member.name) is now the owner" : (error ?? "Failed to transfer ownership"),
                                     type: success ? .success : .error)
        }
    }
    
    func removeMember(_ member: AppUser) {
        guard let uid = member.id else { return }
        store.removeMember(uid) { success, error in
            ToastManager.shared.show(success ? "\(member.name) was removed" : (error ?? "Failed to remove member"),
                                     type: success ? .success : .error)
        }
    }
    
    func uploadImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        isUploadingImage = true
        defer { selectedPhotoItem = nil }
        
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let jpeg = ImageProcessor.squareJPEG(from: uiImage) else {
            isUploadingImage = false
            ToastManager.shared.show("Couldn't load the selected photo", type: .error)
            return
        }
        
        store.setHouseImage(jpeg) { success, error in
            isUploadingImage = false
            ToastManager.shared.show(success ? "House photo updated" : (error ?? "Failed to upload photo"),
                                     type: success ? .success : .error)
        }
    }
    
    func removeImage() {
        store.setHouseImage(nil) { success, error in
            ToastManager.shared.show(success ? "House photo removed" : (error ?? "Failed to remove photo"),
                                     type: success ? .success : .error)
        }
    }
    
    func leaveHouse() {
        isLeaving = true
        store.leaveHouse { success, error in
            isLeaving = false
            if success {
                ToastManager.shared.show("You left the house", type: .success)
                dismiss()
            } else {
                ToastManager.shared.show(error ?? "Failed to leave house", type: .error)
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: AppUser
    let isAdmin: Bool
    let isCreator: Bool
    let canManage: Bool
    let canTransfer: Bool
    let isSelf: Bool
    let balanceText: String?
    let onToggleAdmin: () -> Void
    let onMakeOwner: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: member.name, photoBase64: member.photoBase64, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name + (isSelf ? " (You)" : ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    if isCreator {
                        badge("Owner", color: AppTheme.amber)
                    } else if isAdmin {
                        badge("Admin", color: AppTheme.violet)
                    }
                }
                Text(balanceText ?? "Settled up")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if canManage || canTransfer {
                Menu {
                    if canManage {
                        Button(isAdmin ? "Remove Admin" : "Make Admin", action: onToggleAdmin)
                    }
                    if canTransfer {
                        Button("Make Owner", action: onMakeOwner)
                    }
                    if canManage {
                        Button("Remove from House", role: .destructive, action: onRemove)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Manage \(member.name)")
            }
        }
        .padding(12)
        .glassCard()
    }
    
    func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

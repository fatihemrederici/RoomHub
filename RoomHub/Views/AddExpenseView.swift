import SwiftUI

enum SplitMode: String, CaseIterable, Hashable {
    case equal
    case exact
    
    var label: String {
        switch self {
        case .equal: return "Split equally"
        case .exact: return "Exact amounts"
        }
    }
}

struct AddExpenseView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @Environment(\.dismiss) var dismiss
    
    var editingExpense: Expense? = nil
    
    @AppStorage("profileDisplayCurrency") var defaultCurrencyCode: String = Currency.deviceDefaultCode
    
    @State var title = ""
    @State var amountText = ""
    @State var selectedCategory: ExpenseCategory = .other
    @State var selectedCurrency: Currency = .usd
    @State var date = Date()
    @State var paidBy = ""
    @State var splitMode: SplitMode = .equal
    @State var selectedMemberIds: Set<String> = []
    @State var exactAmounts: [String: String] = [:]
    @State var showCurrencyPicker = false
    @State var showDeleteConfirmation = false
    @State var didLoad = false
    
    var isEditing: Bool { editingExpense != nil }
    
    // MARK: - Derived values
    var amount: Double? { AmountParser.parse(amountText, currency: selectedCurrency) }
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    /// Katılımcılar: evin güncel üyeleri + (düzenlemede) artık evde olmayan eski katılımcılar
    var participants: [AppUser] {
        var list = store.memberList
        if let expense = editingExpense {
            let known = Set(list.compactMap { $0.id })
            let extra = (expense.splitBetween + [expense.paidBy]).filter { !known.contains($0) }
            for uid in Array(Set(extra)).sorted() {
                list.append(AppUser(id: uid, name: store.fullName(for: uid), email: ""))
            }
        }
        return list
    }
    
    /// Ev listesindeki sırayla seçilen kişiler (kuruş dağıtımı deterministik olsun)
    var orderedSelectedIds: [String] {
        participants.compactMap { $0.id }.filter { selectedMemberIds.contains($0) }
    }
    
    var exactValues: [String: Double] {
        var values: [String: Double] = [:]
        for (uid, text) in exactAmounts {
            if let value = AmountParser.parse(text, currency: selectedCurrency), value > 0 {
                values[uid] = value
            }
        }
        return values
    }
    
    var exactRemaining: Double {
        (amount ?? 0) - exactValues.values.reduce(0, +)
    }
    
    var splits: [String: Double] {
        guard let amount = amount, amount > 0 else { return [:] }
        switch splitMode {
        case .equal:
            return DebtCalculator.equalShares(total: amount, memberIds: orderedSelectedIds, currency: selectedCurrency)
        case .exact:
            return exactValues
        }
    }
    
    var validationMessage: String? {
        guard let amount = amount, amount > 0 else { return "Enter an amount" }
        if amount > 100_000_000 { return "That amount is too large" }
        if trimmedTitle.isEmpty { return "Add a title" }
        if trimmedTitle.count > 100 { return "Title is too long" }
        if paidBy.isEmpty { return "Choose who paid" }
        switch splitMode {
        case .equal:
            if selectedMemberIds.isEmpty { return "Select at least one person" }
        case .exact:
            if exactValues.isEmpty { return "Enter at least one amount" }
            if abs(exactRemaining) >= selectedCurrency.minorUnit / 2 {
                return exactRemaining > 0
                    ? "\(selectedCurrency.format(exactRemaining)) left to assign"
                    : "\(selectedCurrency.format(-exactRemaining)) over the total"
            }
        }
        return nil
    }
    
    var isFormValid: Bool { validationMessage == nil }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        amountSection
                        titleSection
                        categorySection
                        dateSection
                        paidBySection
                        splitSection
                        
                        if let message = validationMessage, amount != nil || !trimmedTitle.isEmpty {
                            Text(message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.coral)
                        }
                        
                        PrimaryButton(title: isEditing ? "Update Expense" : "Save Expense", isEnabled: isFormValid) {
                            save()
                        }
                        
                        if isEditing {
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                Label("Delete Expense", systemImage: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.coral)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.coral.opacity(0.1))
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Expense" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: $selectedCurrency)
            }
            .alert("Delete this expense?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteExpense() }
            } message: {
                Text("Balances will be recalculated for everyone in the house.")
            }
            .onAppear(perform: loadInitialValues)
            .onChange(of: store.memberList.count) { _, _ in fillDefaultsIfNeeded() }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    var amountSection: some View {
        VStack(spacing: 10) {
            CurrencyChip(currency: selectedCurrency) { showCurrencyPicker = true }
            
            HStack(spacing: 4) {
                Text(selectedCurrency.symbol)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textMuted)
                TextField(selectedCurrency.usesDecimals ? "0.00" : "0", text: $amountText)
                    .keyboardType(selectedCurrency.usesDecimals ? .decimalPad : .numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onChange(of: amountText) { _, newValue in
                        let cleaned = AmountParser.sanitize(newValue, allowDecimals: selectedCurrency.usesDecimals)
                        if cleaned != newValue { amountText = cleaned }
                    }
                    .accessibilityLabel("Amount")
            }
        }
        .padding(.top, 12)
    }
    
    var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("TITLE")
            ThemedTextField(placeholder: "e.g. Electricity Bill", text: $title)
        }
    }
    
    var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("CATEGORY")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
                ForEach(ExpenseCategory.allCases) { category in
                    CategoryChip(category: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    var dateSection: some View {
        HStack {
            FieldLabel("DATE")
            Spacer()
            DatePicker("", selection: $date, in: ...Date().addingTimeInterval(60 * 60 * 24 * 365), displayedComponents: .date)
                .labelsHidden()
                .tint(AppTheme.mint)
        }
        .padding(12)
        .glassCard()
    }
    
    var paidBySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("PAID BY")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(participants) { member in
                        let uid = member.id ?? ""
                        let isSelected = paidBy == uid
                        Button(action: { paidBy = uid }) {
                            HStack(spacing: 6) {
                                AvatarView(name: member.name, photoBase64: member.photoBase64, size: 24,
                                           color: isSelected ? .white : AppTheme.mint)
                                Text(uid == store.currentUserId ? "You" : member.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? AppTheme.mint.opacity(0.85) : Color.white.opacity(0.06))
                            .cornerRadius(20)
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }
    
    var splitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FieldLabel("SPLIT BETWEEN")
                Spacer()
                if splitMode == .equal {
                    Button(action: toggleSelectAll) {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.mint)
                    }
                }
            }
            
            PillPicker(options: SplitMode.allCases, selection: $splitMode, label: { $0.label }, tint: AppTheme.mint)
            
            VStack(spacing: 8) {
                ForEach(participants) { member in
                    if splitMode == .equal {
                        equalRow(member)
                    } else {
                        exactRow(member)
                    }
                }
            }
            
            if splitMode == .exact, let amount = amount, amount > 0 {
                Text(abs(exactRemaining) < selectedCurrency.minorUnit / 2
                     ? "All assigned ✓"
                     : "Remaining: \(selectedCurrency.format(exactRemaining))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(abs(exactRemaining) < selectedCurrency.minorUnit / 2 ? AppTheme.mint : AppTheme.textMuted)
            }
        }
    }
    
    var allSelected: Bool {
        !participants.isEmpty && participants.allSatisfy { selectedMemberIds.contains($0.id ?? "") }
    }
    
    func equalRow(_ member: AppUser) -> some View {
        let uid = member.id ?? ""
        let isSelected = selectedMemberIds.contains(uid)
        let share = splits[uid]
        return SelectableMemberRow(
            user: member,
            isYou: uid == store.currentUserId,
            isSelected: isSelected,
            trailingText: isSelected ? share.map { selectedCurrency.format($0) } : nil
        ) {
            if isSelected { selectedMemberIds.remove(uid) } else { selectedMemberIds.insert(uid) }
        }
    }
    
    func exactRow(_ member: AppUser) -> some View {
        let uid = member.id ?? ""
        return HStack(spacing: 12) {
            AvatarView(name: member.name, photoBase64: member.photoBase64, size: 36)
            Text(uid == store.currentUserId ? "\(member.name) (You)" : member.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            TextField("0", text: Binding(
                get: { exactAmounts[uid] ?? "" },
                set: { exactAmounts[uid] = AmountParser.sanitize($0, allowDecimals: selectedCurrency.usesDecimals) }
            ))
            .keyboardType(selectedCurrency.usesDecimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 90)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .accessibilityLabel("Amount for \(member.name)")
        }
        .padding(12)
        .glassCard()
    }
    
    // MARK: - Actions
    func toggleSelectAll() {
        if allSelected {
            selectedMemberIds.removeAll()
        } else {
            selectedMemberIds = Set(participants.compactMap { $0.id })
        }
    }
    
    func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        
        if let expense = editingExpense {
            title = expense.title
            selectedCurrency = expense.currency
            amountText = AmountParser.editingString(for: expense.amount, currency: expense.currency)
            selectedCategory = ExpenseCategory(rawValue: expense.category) ?? .other
            date = expense.date
            paidBy = expense.paidBy
            selectedMemberIds = Set(expense.splitBetween.isEmpty ? Array(expense.splits.keys) : expense.splitBetween)
            if expense.isExactSplit {
                splitMode = .exact
                for (uid, value) in expense.splits {
                    exactAmounts[uid] = AmountParser.editingString(for: value, currency: expense.currency)
                }
            }
        } else {
            selectedCurrency = store.baseCurrency
            paidBy = store.currentUserId
            fillDefaultsIfNeeded()
        }
    }
    
    /// Üyeler sonradan yüklenirse varsayılan olarak herkesi seç
    func fillDefaultsIfNeeded() {
        guard editingExpense == nil, selectedMemberIds.isEmpty else { return }
        selectedMemberIds = Set(store.memberIds)
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func save() {
        guard isFormValid, let amount = amount else { return }
        let finalSplits = splits
        guard !finalSplits.isEmpty else { return }
        
        if let original = editingExpense {
            var edited = original
            edited.title = trimmedTitle
            edited.amount = amount
            edited.currencyCode = selectedCurrency.code
            edited.category = selectedCategory.rawValue
            edited.date = date
            edited.paidBy = paidBy
            edited.splits = finalSplits
            edited.splitBetween = participants.compactMap { $0.id }.filter { finalSplits[$0] != nil }
            edited.splitMode = splitMode.rawValue
            
            store.updateExpense(original: original, edited: edited) { success, error in
                if success {
                    ToastManager.shared.show("Expense updated", type: .success)
                } else {
                    ToastManager.shared.show(error ?? "Failed to update expense", type: .error)
                }
            }
        } else {
            store.addExpense(
                title: trimmedTitle,
                amount: amount,
                currency: selectedCurrency,
                category: selectedCategory.rawValue,
                paidBy: paidBy,
                splits: finalSplits,
                splitMode: splitMode.rawValue,
                date: date
            ) { success, error in
                if success {
                    ToastManager.shared.show("Expense added", type: .success)
                } else {
                    ToastManager.shared.show(error ?? "Failed to add expense", type: .error)
                }
            }
        }
        // Firestore önce cihazda yazar; liste hemen güncellenir, sunucu cevabını beklemeden kapat
        dismiss()
    }
    
    func deleteExpense() {
        guard let expense = editingExpense else { return }
        store.deleteExpense(expense) { success, error in
            if success {
                ToastManager.shared.show("Expense deleted", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to delete expense", type: .error)
            }
        }
        dismiss()
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? category.color : Color.white.opacity(0.06))
            )
        }
        .accessibilityLabel(category.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

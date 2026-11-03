import SwiftUI

struct SettlementsView: View {
    @EnvironmentObject var store: HouseStore
    @ObservedObject var rateService = ExchangeRateService.shared
    
    @AppStorage("profileDisplayCurrency") var defaultCurrencyCode: String = Currency.deviceDefaultCode
    @State var currencyOverride: Currency?
    @State var showCurrencyPicker = false
    @State var settlingTransaction: DebtTransaction?
    @State var settlementPendingUndo: Settlement?
    @State var showAllHistory = false
    
    /// Varsayılan olarak evin para birimi gösterilir (bakiyeler bu birimde tutulur)
    var displayCurrency: Currency { currencyOverride ?? store.baseCurrency }
    var me: String { store.currentUserId }
    
    var myTransactions: [DebtTransaction] { store.transactions.filter { $0.from == me || $0.to == me } }
    var otherTransactions: [DebtTransaction] { store.transactions.filter { $0.from != me && $0.to != me } }
    var youAreOwed: Double { myTransactions.filter { $0.to == me }.reduce(0) { $0 + $1.amount } }
    var youOwe: Double { myTransactions.filter { $0.from == me }.reduce(0) { $0 + $1.amount } }
    
    var history: [Settlement] { showAllHistory ? store.settlements : Array(store.settlements.prefix(5)) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        netBalanceCard
                        if store.hasUnconvertibleItems && !rateService.hasRates {
                            InfoBanner(icon: "wifi.exclamationmark",
                                       text: "Exchange rates couldn't be loaded. Some balances may be inaccurate until you're online.")
                        }
                        balancesSection
                        if !otherTransactions.isEmpty { othersSection }
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { rateService.fetchRates() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: Binding(
                    get: { displayCurrency },
                    set: { currencyOverride = $0 }
                ))
            }
            .sheet(item: $settlingTransaction) { tx in
                SettleUpSheet(transaction: tx)
                    .environmentObject(store)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppTheme.background)
            }
            .confirmationDialog(
                "Undo this payment?",
                isPresented: Binding(
                    get: { settlementPendingUndo != nil },
                    set: { if !$0 { settlementPendingUndo = nil } }
                ),
                titleVisibility: .visible,
                presenting: settlementPendingUndo
            ) { settlement in
                Button("Undo Payment", role: .destructive) { undo(settlement) }
                Button("Cancel", role: .cancel) {}
            } message: { settlement in
                Text("\(store.name(for: settlement.fromUser)) → \(store.name(for: settlement.toUser)): \(settlement.currency.format(settlement.amount)). The balance will be restored.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func shown(_ baseValue: Double) -> String {
        displayCurrency.format(store.display(baseValue, in: displayCurrency))
    }
    
    // MARK: - Net Balance Hero
    var netBalanceCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(AppTheme.heroGradient)
                .overlay(
                    Circle()
                        .fill(AppTheme.violet.opacity(0.18))
                        .frame(width: 160, height: 160)
                        .blur(radius: 40)
                        .offset(x: -100, y: 50)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Net Balance")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    CurrencyChip(currency: displayCurrency) { showCurrencyPicker = true }
                }
                
                Text(displayCurrency.formatSigned(store.display(store.myBalance, in: displayCurrency)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(store.myBalance > 0 ? AppTheme.mint : (store.myBalance < 0 ? AppTheme.coral : AppTheme.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You are owed")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Text(shown(youAreOwed))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.mint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You owe")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Text(shown(youOwe))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.coral)
                    }
                }
                
                if displayCurrency.code != store.baseCurrencyCode {
                    Text("House currency is \(store.baseCurrencyCode). Converted at today's rate.")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Balances
    var balancesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Balances")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            if store.isLoadingExpenses || store.isLoadingSettlements {
                ProgressView()
                    .tint(AppTheme.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            } else if myTransactions.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "You're all settled up!",
                               message: "You don't owe anyone and nobody owes you.")
            } else {
                VStack(spacing: 10) {
                    ForEach(myTransactions) { tx in
                        let owedToYou = tx.to == me
                        let otherId = owedToYou ? tx.from : tx.to
                        SettlementCard(
                            name: store.fullName(for: otherId),
                            photoBase64: store.user(otherId)?.photoBase64,
                            label: owedToYou ? "owes you" : "you owe",
                            amount: shown(tx.amount),
                            color: owedToYou ? AppTheme.mint : AppTheme.coral,
                            actionTitle: owedToYou ? "Record" : "Settle",
                            onAction: { settlingTransaction = tx }
                        )
                    }
                }
            }
        }
    }
    
    var othersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Between Roommates")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            VStack(spacing: 10) {
                ForEach(otherTransactions) { tx in
                    SettlementCard(
                        name: store.fullName(for: tx.from),
                        photoBase64: store.user(tx.from)?.photoBase64,
                        label: "owes \(store.fullName(for: tx.to))",
                        amount: shown(tx.amount),
                        color: AppTheme.textSecondary,
                        actionTitle: nil,
                        onAction: {}
                    )
                }
            }
        }
    }
    
    // MARK: - History
    var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Payment History")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if store.settlements.count > 5 {
                    Button(showAllHistory ? "Show less" : "Show all") {
                        withAnimation { showAllHistory.toggle() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.mint)
                }
            }
            
            if store.settlements.isEmpty {
                Text("Payments you record will appear here.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { settlement in
                        historyRow(settlement)
                    }
                }
            }
        }
    }
    
    func historyRow(_ settlement: Settlement) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.violet)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.name(for: settlement.fromUser)) paid \(store.name(for: settlement.toUser))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(settlement.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Text(settlement.currency.format(settlement.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
            if store.canUndo(settlement) {
                Button(action: { settlementPendingUndo = settlement }) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textMuted)
                }
                .accessibilityLabel("Undo payment")
            }
        }
        .padding(12)
        .glassCard()
    }
    
    func undo(_ settlement: Settlement) {
        store.deleteSettlement(settlement) { success, error in
            if success {
                ToastManager.shared.show("Payment undone", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Couldn't undo payment", type: .error)
            }
        }
    }
}

extension Settlement {
    var currency: Currency { Currency.find(currencyCode) }
}

// MARK: - Settle Up Sheet (tam ya da kısmi ödeme)
struct SettleUpSheet: View {
    @EnvironmentObject var store: HouseStore
    @Environment(\.dismiss) var dismiss
    let transaction: DebtTransaction
    
    @State var amountText = ""
    @State var didLoad = false
    
    var currency: Currency { store.baseCurrency }
    var amount: Double? { AmountParser.parse(amountText, currency: currency) }
    var isValid: Bool {
        guard let amount = amount else { return false }
        return amount > 0 && amount <= transaction.amount + currency.minorUnit / 2
    }
    var youPay: Bool { transaction.from == store.currentUserId }
    
    var body: some View {
        VStack(spacing: 18) {
            Text(youPay
                 ? "Pay \(store.fullName(for: transaction.to))"
                 : "\(store.fullName(for: transaction.from)) paid you")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, 24)
            
            Text("Outstanding: \(currency.format(transaction.amount))")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
            
            HStack(spacing: 4) {
                Text(currency.symbol)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textMuted)
                TextField("0", text: $amountText)
                    .keyboardType(currency.usesDecimals ? .decimalPad : .numberPad)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onChange(of: amountText) { _, newValue in
                        let cleaned = AmountParser.sanitize(newValue, allowDecimals: currency.usesDecimals)
                        if cleaned != newValue { amountText = cleaned }
                    }
            }
            
            Text("Pay it in cash or by bank transfer, then record it here. You can enter a partial amount.")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            PrimaryButton(title: "Record Payment", gradient: AppTheme.violetGradient, isEnabled: isValid) {
                record()
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            amountText = AmountParser.editingString(for: currency.rounded(transaction.amount), currency: currency)
        }
    }
    
    func record() {
        guard let amount = amount, isValid else { return }
        let value = min(amount, transaction.amount)
        store.recordSettlement(from: transaction.from, to: transaction.to, amount: value) { success, error in
            if success {
                ToastManager.shared.show("Payment recorded", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to record payment", type: .error)
            }
        }
        dismiss()
    }
}

// MARK: - Settlement Card
struct SettlementCard: View {
    let name: String
    var photoBase64: String? = nil
    let label: String
    let amount: String
    let color: Color
    let actionTitle: String?
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: name, photoBase64: photoBase64, size: 46, color: color)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(amount)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                
                if let actionTitle = actionTitle {
                    Button(action: onAction) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(color)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(14)
        .glassCard()
    }
}

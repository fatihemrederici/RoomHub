import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @ObservedObject var rateService = ExchangeRateService.shared
    
    @AppStorage("profileDisplayCurrency") var defaultCurrencyCode: String = Currency.deviceDefaultCode
    @State var currencyOverride: Currency?
    @State var selectedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    
    @State var showAddExpense = false
    @State var showCurrencyPicker = false
    @State var showHouseManagement = false
    @State var showInsights = false
    @State var editingExpense: Expense?
    @State var expensePendingDelete: Expense?
    
    /// "Settle" hızlı aksiyonu → Settle Up sekmesine geçiş
    var onSettleTap: () -> Void = {}
    
    var displayCurrency: Currency { currencyOverride ?? Currency.find(defaultCurrencyCode) }
    var monthExpenses: [Expense] { store.expenses(inMonthOf: selectedMonth) }
    var isCurrentMonth: Bool { Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        heroCard
                        quickActions
                        if store.hasUnconvertibleItems && !rateService.hasRates {
                            InfoBanner(icon: "wifi.exclamationmark",
                                       text: "Exchange rates couldn't be loaded. Amounts in other currencies may be shown unconverted until you're online.")
                        }
                        monthSelector
                        expenseList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { rateService.fetchRates() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
                    .environmentObject(authVM)
                    .environmentObject(store)
            }
            .sheet(item: $editingExpense) { expense in
                AddExpenseView(editingExpense: expense)
                    .environmentObject(authVM)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showInsights) {
                InsightsView(initialMonth: selectedMonth, displayCurrency: displayCurrency)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: Binding(
                    get: { displayCurrency },
                    set: { currencyOverride = $0 }
                ))
            }
            .sheet(isPresented: $showHouseManagement) {
                HouseManagementView()
                    .environmentObject(authVM)
                    .environmentObject(store)
            }
            .confirmationDialog(
                "Delete this expense?",
                isPresented: Binding(
                    get: { expensePendingDelete != nil },
                    set: { if !$0 { expensePendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: expensePendingDelete
            ) { expense in
                Button("Delete \"\(expense.title)\"", role: .destructive) { delete(expense) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Balances will be recalculated for everyone in the house.")
            }
            .onChange(of: defaultCurrencyCode) { _, _ in currencyOverride = nil }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    var header: some View {
        HStack(spacing: 12) {
            Image("logopng")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .shadow(color: AppTheme.mint.opacity(0.8), radius: 4)
                .shadow(color: AppTheme.mint.opacity(0.5), radius: 12)
                .accessibilityHidden(true)
            
            Spacer()
            
            Button(action: { showHouseManagement = true }) {
                HStack(spacing: 8) {
                    Text(store.house?.houseName ?? "House")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    ZStack {
                        if let image = ImageProcessor.image(fromBase64: store.house?.imageBase64) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(AppTheme.cardGlass)
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(AppTheme.cardGlassBorder, lineWidth: 1))
                            Image(systemName: "house.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.mint)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppTheme.cardGlass))
            }
            .accessibilityLabel("House settings")
        }
    }
    
    // MARK: - Hero Card
    var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(AppTheme.heroGradient)
                .overlay(
                    Circle()
                        .fill(AppTheme.mint.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .blur(radius: 40)
                        .offset(x: 120, y: -60)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isCurrentMonth ? "Spent This Month" : "Spent in \(selectedMonth.formatted(.dateTime.month(.wide)))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    CurrencyChip(currency: displayCurrency) { showCurrencyPicker = true }
                }
                
                Text(displayCurrency.format(store.total(of: monthExpenses, in: displayCurrency)))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                
                HStack(spacing: 16) {
                    Label("\(monthExpenses.count) expenses", systemImage: "list.bullet")
                    Spacer()
                    balancePill
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(minHeight: 170)
    }
    
    var balancePill: some View {
        let balance = store.display(store.myBalance, in: displayCurrency)
        let color = store.myBalance > 0 ? AppTheme.mint : (store.myBalance < 0 ? AppTheme.coral : AppTheme.textSecondary)
        let text: String
        if store.myBalance > 0 {
            text = "You're owed \(displayCurrency.format(balance))"
        } else if store.myBalance < 0 {
            text = "You owe \(displayCurrency.format(abs(balance)))"
        } else {
            text = "All settled"
        }
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(10)
    }
    
    // MARK: - Quick Actions
    var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "plus", label: "Add", gradient: AppTheme.mintGradient) {
                showAddExpense = true
            }
            QuickActionButton(icon: "arrow.left.arrow.right", label: "Settle", gradient: AppTheme.violetGradient) {
                onSettleTap()
            }
            QuickActionButton(icon: "chart.pie.fill", label: "Insights", gradient: AppTheme.amberGradient) {
                showInsights = true
            }
        }
    }
    
    // MARK: - Month selector
    var monthSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.monthsWithExpenses, id: \.self) { month in
                    let isSelected = Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month)
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedMonth = month } }) {
                        Text(monthLabel(month))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? AppTheme.mint.opacity(0.85) : Color.white.opacity(0.06))
                            .cornerRadius(20)
                    }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
    
    func monthLabel(_ month: Date) -> String {
        let sameYear = Calendar.current.isDate(month, equalTo: Date(), toGranularity: .year)
        return sameYear
            ? month.formatted(.dateTime.month(.abbreviated))
            : month.formatted(.dateTime.month(.abbreviated).year())
    }
    
    // MARK: - Expense list
    var expenseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCurrentMonth ? "Recent" : monthLabel(selectedMonth))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            if store.isLoadingExpenses {
                ProgressView()
                    .tint(AppTheme.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if monthExpenses.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: isCurrentMonth ? "No expenses this month" : "No expenses",
                    message: "Tap Add to log a shared expense"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(monthExpenses) { expense in
                        Button(action: { editingExpense = expense }) {
                            ExpenseCard(
                                expense: expense,
                                paidByName: store.name(for: expense.paidBy),
                                currentUserId: store.currentUserId
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(action: { editingExpense = expense }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: { expensePendingDelete = expense }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                Text("Tap an expense to edit · Long press for more")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
    
    func delete(_ expense: Expense) {
        store.deleteExpense(expense) { success, error in
            if success {
                ToastManager.shared.show("Expense deleted", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to delete expense", type: .error)
            }
        }
    }
}

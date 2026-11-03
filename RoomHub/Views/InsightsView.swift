import SwiftUI

struct CategorySlice: Identifiable {
    var id: String { category.rawValue }
    let category: ExpenseCategory
    let amount: Double
    let percentage: Double
}

struct MemberSpending: Identifiable {
    let id: String
    let name: String
    let paid: Double
    let share: Double
}

enum InsightsPeriod: String, CaseIterable, Hashable {
    case month
    case allTime
}

struct InsightsView: View {
    @EnvironmentObject var store: HouseStore
    @Environment(\.dismiss) var dismiss
    
    let initialMonth: Date
    let displayCurrency: Currency
    
    @State var period: InsightsPeriod = .month
    
    var expenses: [Expense] {
        period == .month ? store.expenses(inMonthOf: initialMonth) : store.expenses
    }
    
    func converted(_ expense: Expense) -> Double {
        store.display(store.baseAmount(of: expense), in: displayCurrency)
    }
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + converted($1) }
    }
    
    var categorySlices: [CategorySlice] {
        let total = totalAmount
        guard total > 0 else { return [] }
        var totals: [ExpenseCategory: Double] = [:]
        for expense in expenses {
            let category = ExpenseCategory(rawValue: expense.category) ?? .other
            totals[category, default: 0] += converted(expense)
        }
        return totals
            .map { CategorySlice(category: $0.key, amount: $0.value, percentage: $0.value / total) }
            .sorted { $0.amount > $1.amount }
    }
    
    var memberSpending: [MemberSpending] {
        var paid: [String: Double] = [:]
        var share: [String: Double] = [:]
        for expense in expenses {
            let value = converted(expense)
            paid[expense.paidBy, default: 0] += value
            let factor = expense.amount > 0 ? value / expense.amount : 0
            for (uid, part) in expense.splits {
                share[uid, default: 0] += part * factor
            }
        }
        let ids = Set(paid.keys).union(share.keys)
        return ids
            .map { MemberSpending(id: $0, name: store.name(for: $0), paid: paid[$0] ?? 0, share: share[$0] ?? 0) }
            .sorted { $0.paid > $1.paid }
    }
    
    var maxMemberAmount: Double {
        max(memberSpending.map { max($0.paid, $0.share) }.max() ?? 1, 0.01)
    }
    
    var periodTitle: String {
        initialMonth.formatted(.dateTime.month(.wide).year())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        PillPicker(options: InsightsPeriod.allCases, selection: $period,
                                   label: { $0 == .month ? periodTitle : "All time" }, tint: AppTheme.amber)
                        
                        if expenses.isEmpty {
                            EmptyStateView(icon: "chart.pie", title: "No data yet",
                                           message: "Add some expenses to see insights")
                        } else {
                            totalCard
                            categoryBreakdown
                            memberBreakdown
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Total Card
    var totalCard: some View {
        VStack(spacing: 6) {
            Text("Total Spent")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Text(displayCurrency.format(totalAmount))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(expenses.count) expenses")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }
    
    // MARK: - Category Breakdown
    var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Category")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: 24) {
                DonutChart(slices: categorySlices)
                    .frame(width: 130, height: 130)
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(categorySlices.prefix(5)) { slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.category.color)
                                .frame(width: 8, height: 8)
                            Text(slice.category.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(slice.percentage.formatted(.percent.precision(.fractionLength(0))))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
            }
            
            VStack(spacing: 8) {
                ForEach(categorySlices) { slice in
                    HStack {
                        Image(systemName: slice.category.icon)
                            .font(.system(size: 13))
                            .foregroundColor(slice.category.color)
                            .frame(width: 24)
                        Text(slice.category.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(displayCurrency.format(slice.amount))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .glassCard()
                }
            }
        }
    }
    
    // MARK: - Member Breakdown
    var memberBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("By Roommate")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(AppTheme.mint, "Paid")
                    legendDot(AppTheme.violet, "Share")
                }
            }
            
            VStack(spacing: 12) {
                ForEach(memberSpending) { member in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(member.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(displayCurrency.format(member.paid))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.mint)
                        }
                        bar(value: member.paid, gradient: AppTheme.mintGradient)
                        HStack {
                            Text("Share")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                            Spacer()
                            Text(displayCurrency.format(member.share))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.violet)
                        }
                        bar(value: member.share, gradient: AppTheme.violetGradient)
                    }
                    .padding(12)
                    .glassCard()
                }
            }
        }
    }
    
    func bar(value: Double, gradient: LinearGradient) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 6)
                    .fill(gradient)
                    .frame(width: max(0, geo.size.width * min(value / maxMemberAmount, 1)))
            }
        }
        .frame(height: 8)
    }
    
    func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
    }
}

// MARK: - Donut Chart Component
struct DonutChart: View {
    let slices: [CategorySlice]
    
    var body: some View {
        ZStack {
            ForEach(Array(cumulativeSlices.enumerated()), id: \.offset) { _, item in
                Circle()
                    .trim(from: item.start, to: item.end)
                    .stroke(item.slice.category.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(spacing: 2) {
                Text("\(slices.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(slices.count == 1 ? "category" : "categories")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spending by category chart")
    }
    
    private var cumulativeSlices: [(slice: CategorySlice, start: Double, end: Double)] {
        var result: [(slice: CategorySlice, start: Double, end: Double)] = []
        var cumulative: Double = 0
        for slice in slices {
            let start = cumulative
            cumulative += slice.percentage
            result.append((slice: slice, start: start, end: cumulative))
        }
        return result
    }
}

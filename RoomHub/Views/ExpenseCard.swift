import SwiftUI

struct ExpenseCard: View {
    let expense: Expense
    let paidByName: String
    let currentUserId: String
    
    var category: ExpenseCategory {
        ExpenseCategory(rawValue: expense.category) ?? .other
    }
    
    /// Bu harcamada sizin durumunuz (harcamanın kendi para biriminde)
    var myLine: (text: String, color: Color)? {
        let myShare = expense.splits[currentUserId] ?? 0
        if expense.paidBy == currentUserId {
            let lent = expense.amount - myShare
            guard lent > 0.004 else { return nil }
            return ("You lent \(expense.currency.format(lent))", AppTheme.mint)
        }
        guard myShare > 0.004 else { return ("Not involved", AppTheme.textMuted) }
        return ("Your share \(expense.currency.format(myShare))", AppTheme.coral)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                    .font(.system(size: 18, weight: .medium))
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("Paid by \(paidByName) · \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.currency.format(expense.amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                if let line = myLine {
                    Text(line.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(line.color)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .glassCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

import Foundation
import FirebaseFirestore

struct Expense: Identifiable, Codable {
    @DocumentID var id: String?
    var houseId: String
    var title: String
    var amount: Double
    var currencyCode: String = "USD"
    var category: String
    var paidBy: String
    var splitBetween: [String]
    var splits: [String: Double]
    var date: Date = Date()
    var createdAt: Date = Date()
    var createdBy: String? = nil
    /// "equal" ya da "exact"
    var splitMode: String? = nil
    /// Kayıt anında evin para birimine çevrilmiş tutar (kur değişse de bakiye sabit kalır)
    var baseCurrency: String? = nil
    var baseAmount: Double? = nil
    
    var currency: Currency {
        Currency.find(currencyCode)
    }
    
    var isExactSplit: Bool { splitMode == "exact" }
}

// MARK: - Tolerant decoding (eski / eksik alanlı dokümanlar için)
extension Expense {
    /// Önce normal Codable ile dener; başarısız olursa (ör. eski "currency" alanı,
    /// eksik "createdAt") dokümanı elle okuyarak harcamanın listeden kaybolmasını önler.
    static func from(_ doc: DocumentSnapshot) -> Expense? {
        if let expense = try? doc.data(as: Expense.self) {
            return expense
        }
        guard let data = doc.data(),
              let houseId = data["houseId"] as? String,
              let title = data["title"] as? String,
              let paidBy = data["paidBy"] as? String else {
            print("🔴 Could not decode expense \(doc.documentID)")
            return nil
        }
        
        let amount = (data["amount"] as? NSNumber)?.doubleValue ?? 0
        let currencyCode = (data["currencyCode"] as? String) ?? (data["currency"] as? String) ?? "USD"
        let splitBetween = data["splitBetween"] as? [String] ?? []
        
        var splits: [String: Double] = [:]
        if let rawSplits = data["splits"] as? [String: Any] {
            for (userId, value) in rawSplits {
                splits[userId] = (value as? NSNumber)?.doubleValue ?? 0
            }
        }
        if splits.isEmpty && !splitBetween.isEmpty {
            let share = amount / Double(splitBetween.count)
            for userId in splitBetween { splits[userId] = share }
        }
        
        return Expense(
            id: doc.documentID,
            houseId: houseId,
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            category: data["category"] as? String ?? ExpenseCategory.other.rawValue,
            paidBy: paidBy,
            splitBetween: splitBetween,
            splits: splits,
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            createdBy: data["createdBy"] as? String,
            splitMode: data["splitMode"] as? String,
            baseCurrency: data["baseCurrency"] as? String,
            baseAmount: (data["baseAmount"] as? NSNumber)?.doubleValue
        )
    }
}

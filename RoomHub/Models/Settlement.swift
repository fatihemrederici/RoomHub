import Foundation
import FirebaseFirestore

struct Settlement: Identifiable, Codable {
    @DocumentID var id: String?
    var houseId: String
    var fromUser: String
    var toUser: String
    var amount: Double
    var currencyCode: String = "USD"
    var settled: Bool = true
    var settledAt: Date? = nil
    var createdAt: Date = Date()
    var createdBy: String? = nil
    /// Kayıt anında evin para birimine çevrilmiş tutar (kur değişse de bakiye sabit kalır)
    var baseCurrency: String? = nil
    var baseAmount: Double? = nil
}

extension Settlement {
    static func from(_ doc: DocumentSnapshot) -> Settlement? {
        if let settlement = try? doc.data(as: Settlement.self) {
            return settlement
        }
        guard let data = doc.data(),
              let houseId = data["houseId"] as? String,
              let fromUser = data["fromUser"] as? String,
              let toUser = data["toUser"] as? String else {
            print("🔴 Could not decode settlement \(doc.documentID)")
            return nil
        }
        return Settlement(
            id: doc.documentID,
            houseId: houseId,
            fromUser: fromUser,
            toUser: toUser,
            amount: (data["amount"] as? NSNumber)?.doubleValue ?? 0,
            currencyCode: (data["currencyCode"] as? String) ?? (data["currency"] as? String) ?? "USD",
            settled: data["settled"] as? Bool ?? true,
            settledAt: (data["settledAt"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            createdBy: data["createdBy"] as? String,
            baseCurrency: data["baseCurrency"] as? String,
            baseAmount: (data["baseAmount"] as? NSNumber)?.doubleValue
        )
    }
}

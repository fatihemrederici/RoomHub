import Foundation

struct DebtTransaction: Identifiable, Equatable {
    var id: String { from + "_" + to }
    let from: String   // borçlu
    let to: String     // alacaklı
    let amount: Double // evin ana para biriminde
}

/// Saf hesaplama fonksiyonları (Firebase'e bağımlı değil → test edilebilir)
enum DebtCalculator {
    /// Bakiyelerden en az sayıda ödeme ile borçları kapatan listeyi üretir.
    /// Pozitif bakiye = alacaklı, negatif = borçlu.
    static func simplify(balances: [String: Double], epsilon: Double = 0.005) -> [DebtTransaction] {
        var creditors = balances.filter { $0.value > epsilon }.map { (id: $0.key, amount: $0.value) }
        var debtors = balances.filter { $0.value < -epsilon }.map { (id: $0.key, amount: -$0.value) }
        
        // Aynı veriyle her cihazda aynı sonucu üretmek için deterministik sıralama
        creditors.sort { $0.amount != $1.amount ? $0.amount > $1.amount : $0.id < $1.id }
        debtors.sort { $0.amount != $1.amount ? $0.amount > $1.amount : $0.id < $1.id }
        
        var result: [DebtTransaction] = []
        var ci = 0, di = 0
        while ci < creditors.count && di < debtors.count {
            let amount = min(creditors[ci].amount, debtors[di].amount)
            if amount > epsilon {
                result.append(DebtTransaction(from: debtors[di].id, to: creditors[ci].id, amount: amount))
            }
            creditors[ci].amount -= amount
            debtors[di].amount -= amount
            if creditors[ci].amount <= epsilon { ci += 1 }
            if debtors[di].amount <= epsilon { di += 1 }
        }
        return result
    }
    
    /// Toplamı kuruşu kuruşuna eşit paylara böler; artan kuruşlar listedeki ilk kişilere dağıtılır.
    /// Örn. 10,00 / 3 → 3,34 + 3,33 + 3,33 (toplam tam 10,00)
    static func equalShares(total: Double, memberIds: [String], currency: Currency) -> [String: Double] {
        guard !memberIds.isEmpty else { return [:] }
        let unit = currency.minorUnit
        let totalUnits = Int((total / unit).rounded())
        let baseUnits = totalUnits / memberIds.count
        let remainder = totalUnits - baseUnits * memberIds.count
        
        var shares: [String: Double] = [:]
        for (index, memberId) in memberIds.enumerated() {
            let units = baseUnits + (index < remainder ? 1 : 0)
            shares[memberId] = Double(units) * unit
        }
        return shares
    }
}

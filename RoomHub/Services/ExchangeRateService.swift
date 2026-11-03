import Foundation
import Combine

/// Ücretsiz ve anahtarsız open.er-api.com servisinden günlük kurları çeker.
/// Kurlar cihazda saklanır; böylece internetsiz açılışta da son bilinen kurlar kullanılır.
class ExchangeRateService: ObservableObject {
    static let shared = ExchangeRateService()
    
    @Published private(set) var rates: [String: Double] = ["USD": 1.0]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var lastFetchFailed = false
    
    private let cacheDuration: TimeInterval = 60 * 60 * 6   // 6 saat
    private let ratesKey = "exchangeRates.rates"
    private let dateKey = "exchangeRates.date"
    
    private init() {
        loadCache()
    }
    
    /// Kurlar hiç yüklenmediyse false (sadece aynı para birimleri arası hesap yapılabilir)
    var hasRates: Bool { rates.count > 1 }
    
    func fetchRatesIfNeeded() {
        if let last = lastUpdated, Date().timeIntervalSince(last) < cacheDuration, hasRates {
            return
        }
        fetchRates()
    }
    
    func fetchRates() {
        guard !isLoading, let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            var decoded: ExchangeRateResponse?
            if let data = data, error == nil {
                decoded = try? JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let decoded = decoded, decoded.rates.count > 1 {
                    self.rates = decoded.rates
                    self.lastUpdated = Date()
                    self.lastFetchFailed = false
                    self.saveCache()
                } else {
                    print("🔴 Exchange rate fetch failed: \(error?.localizedDescription ?? "decode error")")
                    self.lastFetchFailed = true
                }
            }
        }.resume()
    }
    
    /// Dönüşüm yapılabiliyorsa sonucu, kur yoksa nil döner
    func convertIfPossible(_ amount: Double, from fromCode: String, to toCode: String) -> Double? {
        if fromCode == toCode { return amount }
        guard let fromRate = rates[fromCode], let toRate = rates[toCode], fromRate > 0 else {
            return nil
        }
        return amount / fromRate * toRate
    }
    
    /// Kur bulunamazsa tutarı olduğu gibi döner (ekranda "kur yok" uyarısı ayrıca gösterilir)
    func convert(_ amount: Double, from fromCode: String, to toCode: String) -> Double {
        convertIfPossible(amount, from: fromCode, to: toCode) ?? amount
    }
    
    func canConvert(from fromCode: String, to toCode: String) -> Bool {
        convertIfPossible(1, from: fromCode, to: toCode) != nil
    }
    
    // MARK: - Cache
    private func loadCache() {
        let defaults = UserDefaults.standard
        if let saved = defaults.dictionary(forKey: ratesKey) as? [String: Double], saved.count > 1 {
            rates = saved
            lastUpdated = defaults.object(forKey: dateKey) as? Date
        }
    }
    
    private func saveCache() {
        let defaults = UserDefaults.standard
        defaults.set(rates, forKey: ratesKey)
        defaults.set(lastUpdated, forKey: dateKey)
    }
}

nonisolated struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

import Foundation

struct Currency: Identifiable, Codable, Hashable {
    let code: String       // ISO 4217 kodu (USD, EUR, vs)
    let symbol: String
    let flag: String
    let name: String
    
    var id: String { code }
    
    /// Ondalık kullanmayan para birimleri
    static let noDecimalCodes: Set<String> = ["JPY", "KRW", "VND", "IDR", "HUF", "ISK", "CLP"]
    
    var usesDecimals: Bool { !Currency.noDecimalCodes.contains(code) }
    
    /// Bir para biriminin en küçük birimi (kuruş = 0.01, yen = 1)
    var minorUnit: Double { usesDecimals ? 0.01 : 1 }
    
    /// Cihaz diline uygun biçim: pl_PL → "12,50 zł", en_US → "PLN 12.50", tr_TR → "₺12,50"
    func format(_ amount: Double) -> String {
        let digits = usesDecimals ? 2 : 0
        return amount.formatted(
            .currency(code: code)
                .precision(.fractionLength(digits))
                .locale(Locale.current)
        )
    }
    
    /// "+12,50 zł" / "-12,50 zł"
    func formatSigned(_ amount: Double) -> String {
        let sign = amount >= 0 ? "+" : "-"
        return sign + format(abs(amount))
    }
    
    /// Tutarı para biriminin hassasiyetine yuvarlar
    func rounded(_ amount: Double) -> Double {
        usesDecimals ? (amount * 100).rounded() / 100 : amount.rounded()
    }
}

extension Currency {
    // MARK: - En Çok Kullanılan 50 Para Birimi
    static let all: [Currency] = [
        Currency(code: "USD", symbol: "$", flag: "🇺🇸", name: "US Dollar"),
        Currency(code: "EUR", symbol: "€", flag: "🇪🇺", name: "Euro"),
        Currency(code: "GBP", symbol: "£", flag: "🇬🇧", name: "British Pound"),
        Currency(code: "JPY", symbol: "¥", flag: "🇯🇵", name: "Japanese Yen"),
        Currency(code: "CNY", symbol: "¥", flag: "🇨🇳", name: "Chinese Yuan"),
        Currency(code: "CHF", symbol: "Fr", flag: "🇨🇭", name: "Swiss Franc"),
        Currency(code: "CAD", symbol: "$", flag: "🇨🇦", name: "Canadian Dollar"),
        Currency(code: "AUD", symbol: "$", flag: "🇦🇺", name: "Australian Dollar"),
        Currency(code: "NZD", symbol: "$", flag: "🇳🇿", name: "New Zealand Dollar"),
        Currency(code: "TRY", symbol: "₺", flag: "🇹🇷", name: "Turkish Lira"),
        Currency(code: "RUB", symbol: "₽", flag: "🇷🇺", name: "Russian Ruble"),
        Currency(code: "INR", symbol: "₹", flag: "🇮🇳", name: "Indian Rupee"),
        Currency(code: "BRL", symbol: "R$", flag: "🇧🇷", name: "Brazilian Real"),
        Currency(code: "ZAR", symbol: "R", flag: "🇿🇦", name: "South African Rand"),
        Currency(code: "KRW", symbol: "₩", flag: "🇰🇷", name: "South Korean Won"),
        Currency(code: "MXN", symbol: "$", flag: "🇲🇽", name: "Mexican Peso"),
        Currency(code: "SGD", symbol: "$", flag: "🇸🇬", name: "Singapore Dollar"),
        Currency(code: "HKD", symbol: "$", flag: "🇭🇰", name: "Hong Kong Dollar"),
        Currency(code: "SEK", symbol: "kr", flag: "🇸🇪", name: "Swedish Krona"),
        Currency(code: "NOK", symbol: "kr", flag: "🇳🇴", name: "Norwegian Krone"),
        Currency(code: "DKK", symbol: "kr", flag: "🇩🇰", name: "Danish Krone"),
        Currency(code: "PLN", symbol: "zł", flag: "🇵🇱", name: "Polish Zloty"),
        Currency(code: "THB", symbol: "฿", flag: "🇹🇭", name: "Thai Baht"),
        Currency(code: "IDR", symbol: "Rp", flag: "🇮🇩", name: "Indonesian Rupiah"),
        Currency(code: "MYR", symbol: "RM", flag: "🇲🇾", name: "Malaysian Ringgit"),
        Currency(code: "PHP", symbol: "₱", flag: "🇵🇭", name: "Philippine Peso"),
        Currency(code: "VND", symbol: "₫", flag: "🇻🇳", name: "Vietnamese Dong"),
        Currency(code: "CZK", symbol: "Kč", flag: "🇨🇿", name: "Czech Koruna"),
        Currency(code: "HUF", symbol: "Ft", flag: "🇭🇺", name: "Hungarian Forint"),
        Currency(code: "ILS", symbol: "₪", flag: "🇮🇱", name: "Israeli Shekel"),
        Currency(code: "AED", symbol: "د.إ", flag: "🇦🇪", name: "UAE Dirham"),
        Currency(code: "SAR", symbol: "﷼", flag: "🇸🇦", name: "Saudi Riyal"),
        Currency(code: "QAR", symbol: "﷼", flag: "🇶🇦", name: "Qatari Riyal"),
        Currency(code: "KWD", symbol: "د.ك", flag: "🇰🇼", name: "Kuwaiti Dinar"),
        Currency(code: "EGP", symbol: "£", flag: "🇪🇬", name: "Egyptian Pound"),
        Currency(code: "NGN", symbol: "₦", flag: "🇳🇬", name: "Nigerian Naira"),
        Currency(code: "KES", symbol: "KSh", flag: "🇰🇪", name: "Kenyan Shilling"),
        Currency(code: "GHS", symbol: "₵", flag: "🇬🇭", name: "Ghanaian Cedi"),
        Currency(code: "MAD", symbol: "د.م.", flag: "🇲🇦", name: "Moroccan Dirham"),
        Currency(code: "UAH", symbol: "₴", flag: "🇺🇦", name: "Ukrainian Hryvnia"),
        Currency(code: "RON", symbol: "lei", flag: "🇷🇴", name: "Romanian Leu"),
        Currency(code: "BGN", symbol: "лв", flag: "🇧🇬", name: "Bulgarian Lev"),
        Currency(code: "PKR", symbol: "₨", flag: "🇵🇰", name: "Pakistani Rupee"),
        Currency(code: "BDT", symbol: "৳", flag: "🇧🇩", name: "Bangladeshi Taka"),
        Currency(code: "LKR", symbol: "₨", flag: "🇱🇰", name: "Sri Lankan Rupee"),
        Currency(code: "KZT", symbol: "₸", flag: "🇰🇿", name: "Kazakhstani Tenge"),
        Currency(code: "ARS", symbol: "$", flag: "🇦🇷", name: "Argentine Peso"),
        Currency(code: "CLP", symbol: "$", flag: "🇨🇱", name: "Chilean Peso"),
        Currency(code: "COP", symbol: "$", flag: "🇨🇴", name: "Colombian Peso"),
        Currency(code: "PEN", symbol: "S/", flag: "🇵🇪", name: "Peruvian Sol"),
        Currency(code: "TWD", symbol: "NT$", flag: "🇹🇼", name: "New Taiwan Dollar"),
    ]
    
    static let usd = all[0]
    
    static func find(_ code: String) -> Currency {
        all.first(where: { $0.code == code }) ?? .usd
    }
    
    static func isSupported(_ code: String) -> Bool {
        all.contains(where: { $0.code == code })
    }
    
    /// Cihazın bölge ayarına göre varsayılan para birimi (Polonya → PLN), desteklenmiyorsa USD
    static let deviceDefaultCode: String = {
        if let code = Locale.current.currency?.identifier, Currency.isSupported(code) {
            return code
        }
        return "USD"
    }()
}

extension Currency {
    // En çok kullanılan 3 para birimi (liste başında ayrı gösterilecek)
    static let popularCodes = ["USD", "EUR", "GBP"]
    
    static var popular: [Currency] {
        popularCodes.compactMap { code in all.first(where: { $0.code == code }) }
    }
    
    // Geri kalan tüm para birimleri, alfabetik (isme göre)
    static var others: [Currency] {
        all
            .filter { !popularCodes.contains($0.code) }
            .sorted { $0.name < $1.name }
    }
}

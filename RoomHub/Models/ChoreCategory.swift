import SwiftUI

enum ChoreIcon {
    /// Görev başlığına göre simge (İngilizce, Türkçe ve Lehçe anahtar kelimeler)
    static func icon(for title: String) -> String {
        let lower = title.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { lower.contains($0) } }
        
        if has(["dish", "bulaşık", "naczy", "zmywar"]) { return "fork.knife" }
        if has(["trash", "garbage", "recycl", "çöp", "śmie"]) { return "trash.fill" }
        if has(["laundry", "çamaşır", "pranie", "ubra"]) { return "washer.fill" }
        if has(["bathroom", "toilet", "shower", "banyo", "tuvalet", "łazien", "toalet"]) { return "shower.fill" }
        if has(["grocer", "shopping", "buy", "market", "alışveriş", "zakup", "sklep"]) { return "cart.fill" }
        if has(["plant", "water", "bitki", "sula", "kwiat", "podlać"]) { return "leaf.fill" }
        if has(["vacuum", "süpür", "odkurz"]) { return "wind" }
        if has(["clean", "sweep", "mop", "dust", "temiz", "sprząt", "myć", "umyć"]) { return "sparkles" }
        if has(["bed", "sheet", "yatak", "pościel"]) { return "bed.double.fill" }
        if has(["cook", "yemek", "gotow"]) { return "frying.pan.fill" }
        return "checkmark.circle.fill"
    }
}

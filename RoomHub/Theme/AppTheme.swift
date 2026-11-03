import SwiftUI

enum AppTheme {
    // Backgrounds
    static let background = Color(hex: "0B0F1A")
    static let cardGlass = Color.white.opacity(0.06)
    static let cardGlassBorder = Color.white.opacity(0.1)
    
    // Text
    static let textPrimary = Color(hex: "F8FAFC")
    static let textSecondary = Color(hex: "94A3B8")
    static let textMuted = Color(hex: "5B6478")
    
    // Accents
    static let mint = Color(hex: "2DD4BF")
    static let coral = Color(hex: "FB7185")
    static let violet = Color(hex: "8B5CF6")
    static let amber = Color(hex: "FBBF24")
    
    // Hero Card Gradient
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "14203A"), Color(hex: "1E2A4A"), Color(hex: "2D1B4E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mintGradient = LinearGradient(
        colors: [Color(hex: "2DD4BF"), Color(hex: "0D9488")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let violetGradient = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let amberGradient = LinearGradient(
        colors: [Color(hex: "FBBF24"), Color(hex: "D97706")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let disabledGradient = LinearGradient(
        colors: [Color(hex: "5B6478"), Color(hex: "5B6478")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Corner radius scale
    static let radiusSmall: CGFloat = 12
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 28
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// Reusable glass card modifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(AppTheme.cardGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

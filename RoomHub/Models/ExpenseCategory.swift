import Foundation
import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case rent = "Rent"
    case utilities = "Utilities"
    case groceries = "Groceries"
    case household = "Household"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .rent: return "house.fill"
        case .utilities: return "bolt.fill"
        case .groceries: return "cart.fill"
        case .household: return "sparkles"
        case .transport: return "car.fill"
        case .entertainment: return "tv.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .rent: return .blue
        case .utilities: return .orange
        case .groceries: return .green
        case .household: return Color(hex: "2DD4BF")
        case .transport: return Color(hex: "F472B6")
        case .entertainment: return .purple
        case .other: return .gray
        }
    }
}

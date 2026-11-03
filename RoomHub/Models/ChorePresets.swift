import SwiftUI

struct ChorePreset: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct ChoreCategoryGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let chores: [ChorePreset]
}

extension ChoreCategoryGroup {
    static let all: [ChoreCategoryGroup] = [
        ChoreCategoryGroup(
            name: "Kitchen",
            icon: "fork.knife",
            color: AppTheme.mint,
            chores: [
                ChorePreset(title: "Wash Dishes", icon: "fork.knife"),
                ChorePreset(title: "Clean Kitchen Counter", icon: "sparkles"),
                ChorePreset(title: "Take Out Trash", icon: "trash.fill"),
                ChorePreset(title: "Clean Fridge", icon: "snowflake"),
                ChorePreset(title: "Wipe Stove", icon: "flame.fill"),
                ChorePreset(title: "Empty Dishwasher", icon: "tray.fill")
            ]
        ),
        ChoreCategoryGroup(
            name: "Bathroom",
            icon: "shower.fill",
            color: AppTheme.violet,
            chores: [
                ChorePreset(title: "Clean Bathroom", icon: "shower.fill"),
                ChorePreset(title: "Scrub Toilet", icon: "toilet.fill"),
                ChorePreset(title: "Clean Mirror", icon: "sparkles"),
                ChorePreset(title: "Restock Toilet Paper", icon: "cart.fill"),
                ChorePreset(title: "Wash Bath Mats", icon: "washer.fill")
            ]
        ),
        ChoreCategoryGroup(
            name: "Cleaning",
            icon: "sparkles",
            color: AppTheme.amber,
            chores: [
                ChorePreset(title: "Sweep Floors", icon: "sparkles"),
                ChorePreset(title: "Vacuum Living Room", icon: "wind"),
                ChorePreset(title: "Mop Floors", icon: "drop.fill"),
                ChorePreset(title: "Dust Surfaces", icon: "sparkle"),
                ChorePreset(title: "Clean Windows", icon: "rectangle.fill")
            ]
        ),
        ChoreCategoryGroup(
            name: "Laundry",
            icon: "washer.fill",
            color: AppTheme.coral,
            chores: [
                ChorePreset(title: "Do Laundry", icon: "washer.fill"),
                ChorePreset(title: "Fold Laundry", icon: "tshirt.fill"),
                ChorePreset(title: "Change Bedsheets", icon: "bed.double.fill"),
                ChorePreset(title: "Iron Clothes", icon: "flame")
            ]
        ),
        ChoreCategoryGroup(
            name: "Shopping",
            icon: "cart.fill",
            color: AppTheme.mint,
            chores: [
                ChorePreset(title: "Buy Groceries", icon: "cart.fill"),
                ChorePreset(title: "Buy Cleaning Supplies", icon: "bubbles.and.sparkles"),
                ChorePreset(title: "Refill Water/Gas", icon: "flame.fill")
            ]
        ),
        ChoreCategoryGroup(
            name: "Outdoor",
            icon: "leaf.fill",
            color: AppTheme.violet,
            chores: [
                ChorePreset(title: "Water Plants", icon: "drop.fill"),
                ChorePreset(title: "Take Out Recycling", icon: "arrow.3.trianglepath"),
                ChorePreset(title: "Sweep Balcony/Porch", icon: "leaf.fill")
            ]
        )
    ]
}

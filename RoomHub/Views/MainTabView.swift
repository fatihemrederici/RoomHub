import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var store: HouseStore
    @State private var selectedTab = 0
    
    init(houseId: String, userId: String) {
        _store = StateObject(wrappedValue: HouseStore(houseId: houseId, currentUserId: userId))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExpensesView(onSettleTap: { selectedTab = 1 })
                .tabItem { Label("Expenses", systemImage: "dollarsign.circle") }
                .tag(0)
            
            SettlementsView()
                .tabItem { Label("Settle Up", systemImage: "arrow.left.arrow.right.circle") }
                .tag(1)
            
            ChoresView()
                .tabItem { Label("Chores", systemImage: "checklist") }
                .tag(2)
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(3)
        }
        .tint(AppTheme.mint)
        .environmentObject(store)
    }
}

import SwiftUI

@main
struct RoomHubApp: App {
    init() {
        FirebaseService.configureIfNeeded()
        _ = ToastWindowManager.shared
        ExchangeRateService.shared.fetchRatesIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

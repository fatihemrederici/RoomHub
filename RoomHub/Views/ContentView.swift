import SwiftUI

struct ContentView: View {
    @StateObject var authVM = AuthViewModel()
    
    var body: some View {
        Group {
            if authVM.isCheckingAuth {
                SplashView()
            } else if authVM.isLoggedIn {
                // holdHouseSetup: yeni ev oluşturulduysa davet kodu gösterilene kadar kurulumda kal
                if let user = authVM.currentUser, let houseId = user.houseId, let userId = user.id,
                   !authVM.holdHouseSetup {
                    MainTabView(houseId: houseId, userId: userId)
                        .id(houseId)   // farklı eve geçince tüm veriler sıfırdan yüklensin
                } else {
                    HouseSetupView()
                }
            } else {
                AuthFlowView()
            }
        }
        .environmentObject(authVM)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

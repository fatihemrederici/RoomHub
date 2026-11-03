import SwiftUI

struct HouseSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State var showCreateHouse = false
    @State var showJoinHouse = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Image("logopng")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .shadow(color: AppTheme.mint.opacity(0.6), radius: 10)
                    .accessibilityHidden(true)
                
                VStack(spacing: 8) {
                    Text("Let's get you set up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Create a new house or join an existing one")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 14) {
                    Button(action: { showCreateHouse = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.mintGradient)
                                    .frame(width: 46, height: 46)
                                Image(systemName: "house.fill")
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create a House")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Start fresh and invite your roommates")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(16)
                        .glassCard()
                    }
                    
                    Button(action: { showJoinHouse = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.violetGradient)
                                    .frame(width: 46, height: 46)
                                Image(systemName: "key.fill")
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Join a House")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Enter an invite code")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(16)
                        .glassCard()
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
                
                // Kurulum ekranında takılı kalmamak için çıkış seçeneği
                Button(action: { authVM.logout() }) {
                    Text("Log out")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showCreateHouse) {
            CreateHouseView().environmentObject(authVM)
        }
        .fullScreenCover(isPresented: $showJoinHouse) {
            JoinHouseView().environmentObject(authVM)
        }
    }
}

#Preview {
    HouseSetupView().environmentObject(AuthViewModel())
}

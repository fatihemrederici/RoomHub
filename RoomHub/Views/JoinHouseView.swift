import SwiftUI

struct JoinHouseView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var houseVM = HouseViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State var code = ""
    
    var isValid: Bool { code.count == 6 }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("INVITE CODE")
                        TextField("A3F9K2", text: $code)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(18)
                            .glassCard()
                            .onChange(of: code) { _, newValue in
                                // Sadece harf/rakam, büyük harf, en fazla 6 karakter
                                let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                                if cleaned != newValue { code = cleaned }
                            }
                        Text("Ask a roommate for the code. They can find it under House → Invite Code.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.leading, 4)
                    }
                    
                    if let error = houseVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.coral)
                            .multilineTextAlignment(.center)
                    }
                    
                    PrimaryButton(title: "Join House", gradient: AppTheme.violetGradient,
                                  isEnabled: isValid, isLoading: houseVM.isLoading) {
                        joinHouse()
                    }
                    
                    Spacer()
                }
                .padding(24)
                .padding(.top, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .navigationTitle("Join House")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
    
    func joinHouse() {
        houseVM.errorMessage = nil
        houseVM.joinHouse(inviteCode: code) { success, error in
            if success {
                ToastManager.shared.show("Welcome to your new house!", type: .success)
                // Kullanıcı dokümanı canlı dinlendiği için ana ekran otomatik açılır
            } else {
                houseVM.errorMessage = error
            }
        }
    }
}

#Preview {
    JoinHouseView().environmentObject(AuthViewModel())
}

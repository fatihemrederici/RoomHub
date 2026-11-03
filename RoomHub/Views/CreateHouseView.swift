import SwiftUI

struct CreateHouseView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var houseVM = HouseViewModel()
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("profileDisplayCurrency") var defaultCurrencyCode: String = Currency.deviceDefaultCode
    
    @State var houseName = ""
    @State var currency: Currency = .usd
    @State var showCurrencyPicker = false
    @State var showSuccessAlert = false
    @State var generatedCode = ""
    @State var didLoad = false
    
    var trimmedName: String { houseName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty && trimmedName.count <= 40 }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("HOUSE NAME")
                        ThemedTextField(placeholder: "e.g. Downtown Apartment", text: $houseName)
                        if trimmedName.count > 40 {
                            Text("Keep it under 40 characters")
                                .font(.caption)
                                .foregroundColor(AppTheme.coral)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("HOUSE CURRENCY")
                        Button(action: { showCurrencyPicker = true }) {
                            HStack(spacing: 12) {
                                Text(currency.flag).font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currency.code)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(currency.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(14)
                            .glassCard()
                        }
                        Text("Balances are kept in this currency. You can still log expenses in any currency.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.leading, 4)
                    }
                    
                    if let error = houseVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.coral)
                    }
                    
                    PrimaryButton(title: "Create House", isEnabled: isValid, isLoading: houseVM.isLoading) {
                        createHouse()
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
                        .disabled(houseVM.isLoading)
                }
            }
            .navigationTitle("Create House")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selectedCurrency: $currency)
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                currency = Currency.find(defaultCurrencyCode)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(houseVM.isLoading || showSuccessAlert)
        .alert("House Created! 🎉", isPresented: $showSuccessAlert) {
            Button("Copy Code & Continue") {
                UIPasteboard.general.string = generatedCode
                authVM.holdHouseSetup = false
            }
        } message: {
            Text("Your invite code is \(generatedCode).\nShare it with your roommates so they can join.")
        }
    }
    
    func createHouse() {
        guard isValid else { return }
        houseVM.errorMessage = nil
        // Kullanıcı davet kodunu görene kadar ana ekrana geçişi beklet
        authVM.holdHouseSetup = true
        houseVM.createHouse(name: trimmedName, currencyCode: currency.code) { success, codeOrError in
            if success {
                generatedCode = codeOrError ?? ""
                showSuccessAlert = true
            } else {
                authVM.holdHouseSetup = false
                houseVM.errorMessage = codeOrError
            }
        }
    }
}

#Preview {
    CreateHouseView().environmentObject(AuthViewModel())
}

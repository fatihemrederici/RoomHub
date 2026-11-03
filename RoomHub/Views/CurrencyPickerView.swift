import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: Currency
    @Environment(\.dismiss) var dismiss
    @State var searchText = ""
    
    var filteredPopular: [Currency] {
        searchText.isEmpty ? Currency.popular : Currency.popular.filter(matchesSearch)
    }
    
    var filteredOthers: [Currency] {
        Currency.others.filter { searchText.isEmpty || matchesSearch($0) }
    }
    
    func matchesSearch(_ currency: Currency) -> Bool {
        currency.name.localizedCaseInsensitiveContains(searchText) ||
        currency.code.localizedCaseInsensitiveContains(searchText)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                List {
                    if !filteredPopular.isEmpty {
                        Section("Popular") {
                            ForEach(filteredPopular) { currency in
                                currencyRow(currency)
                            }
                        }
                    }
                    
                    if !filteredOthers.isEmpty {
                        Section("All Currencies") {
                            ForEach(filteredOthers) { currency in
                                currencyRow(currency)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.mint)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    func currencyRow(_ currency: Currency) -> some View {
        Button(action: {
            selectedCurrency = currency
            dismiss()
        }) {
            HStack(spacing: 12) {
                Text(currency.flag)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(currency.name)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                if currency.code == selectedCurrency.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.mint)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppTheme.cardGlass)
    }
}

#Preview {
    CurrencyPickerView(selectedCurrency: .constant(.usd))
}

import SwiftUI

/// Uygulama içi gizlilik politikası (App Store'a verilecek web sayfasıyla aynı metin)
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Last updated: \(AppConfig.privacyPolicyLastUpdated)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                        
                        section("Who we are",
                                "RoomHub is developed by \(AppConfig.developerName). It helps roommates share expenses and chores. Contact: \(AppConfig.supportEmail)")
                        section("What we collect",
                                "• Account info: your name, email address and password (passwords are handled by Firebase Authentication and never visible to us).\n• Optional profile and house photos you choose to upload.\n• Content you create: houses, expenses, payments and chores.")
                        section("How we use it",
                                "Only to run the app: to sign you in and to show your shared house data to the roommates in your house. We do not sell your data, show ads, or track you across other apps or websites.")
                        section("Who can see your data",
                                "Your name, photo and the house data are visible only to members of the same house. Data is stored with Google Firebase (Cloud Firestore and Firebase Authentication). Exchange rates are loaded from open.er-api.com; no personal data is sent to that service.")
                        section("Data retention & deletion",
                                "You can delete your account at any time in Profile → Delete Account. This deletes your profile and removes you from your house. Shared expenses and payments that involve other roommates stay in their house history (with your name) so their balances remain correct. If you are the last member, the house and all its data are deleted.")
                        section("Children",
                                "RoomHub is not directed at children under 13.")
                        section("Changes",
                                "If this policy changes, the updated version will be shown in the app.")
                        section("Contact",
                                "Questions or requests: \(AppConfig.supportEmail)")
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

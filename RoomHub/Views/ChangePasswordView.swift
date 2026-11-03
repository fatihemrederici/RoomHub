import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State var currentPassword = ""
    @State var newPassword = ""
    @State var confirmPassword = ""
    @State var isSaving = false
    @State var errorMessage: String?
    
    var isValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword && newPassword != currentPassword
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ThemedTextField(placeholder: "Current password", text: $currentPassword,
                                        isSecure: true, contentType: .password)
                        ThemedTextField(placeholder: "New password (min. 6 characters)", text: $newPassword,
                                        isSecure: true, contentType: .newPassword)
                        ThemedTextField(placeholder: "Confirm new password", text: $confirmPassword,
                                        isSecure: true, contentType: .newPassword)
                        
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            hint("Passwords don't match")
                        } else if !newPassword.isEmpty && newPassword.count < 6 {
                            hint("Password must be at least 6 characters")
                        }
                        if let errorMessage = errorMessage {
                            hint(errorMessage)
                        }
                        
                        PrimaryButton(title: "Update Password", gradient: AppTheme.violetGradient,
                                      isEnabled: isValid, isLoading: isSaving) {
                            save()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func hint(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func save() {
        errorMessage = nil
        isSaving = true
        authVM.changePassword(current: currentPassword, new: newPassword) { success, error in
            isSaving = false
            if success {
                ToastManager.shared.show("Password updated", type: .success)
                dismiss()
            } else {
                errorMessage = error ?? "Couldn't update password"
            }
        }
    }
}

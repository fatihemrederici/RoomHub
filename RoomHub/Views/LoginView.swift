import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var onSwitchToSignUp: () -> Void = {}
    
    @State private var email = ""
    @State private var password = ""
    @State private var showResetAlert = false
    @State private var resetEmail = ""
    
    init(onSwitchToSignUp: @escaping () -> Void = {}) {
        self.onSwitchToSignUp = onSwitchToSignUp
    }
    
    var canSubmit: Bool {
        email.contains("@") && !password.isEmpty && !authVM.isLoading
    }
    
    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.7)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        .padding(.bottom, 32)
                    
                    heading
                        .padding(.bottom, 32)
                        .entrance(delay: 0.05)
                    
                    form
                        .entrance(delay: 0.15)
                    
                    footer
                        .padding(.top, 28)
                        .entrance(delay: 0.25)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .onAppear { authVM.errorMessage = nil }
        .alert("Reset Password", isPresented: $showResetAlert) {
            TextField("Email", text: $resetEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Send Link") { sendReset() }
        } message: {
            Text("We'll email you a link to reset your password.")
        }
    }
    
    // MARK: - Parts
    private var topBar: some View {
        HStack {
            AuthBackButton { dismiss() }
            Spacer()
            GlowingLogo(size: 30)
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
    }
    
    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back 👋")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("Log in to see what's new in your house.")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
    
    private var form: some View {
        VStack(spacing: 14) {
            AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email,
                          keyboard: .emailAddress, contentType: .emailAddress, submitLabel: .next)
            
            AuthTextField(icon: "lock.fill", placeholder: "Password", text: $password,
                          isSecure: true, contentType: .password, submitLabel: .go,
                          onSubmit: submit)
            
            HStack {
                Spacer()
                Button("Forgot password?") {
                    resetEmail = email
                    showResetAlert = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.mint)
            }
            .padding(.bottom, 6)
            
            if let error = authVM.errorMessage {
                AuthErrorBanner(message: error)
            }
            
            AuthPrimaryButton(title: "Log In", isEnabled: canSubmit, isLoading: authVM.isLoading, action: submit)
                .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.25), value: authVM.errorMessage)
    }
    
    private var footer: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("New to RoomHub?")
                .foregroundColor(AppTheme.textSecondary)
            Button("Create an account", action: onSwitchToSignUp)
                .foregroundColor(AppTheme.mint)
                .fontWeight(.bold)
            Spacer()
        }
        .font(.system(size: 14))
    }
    
    // MARK: - Actions
    private func submit() {
        guard canSubmit else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        authVM.login(email: email, password: password)
    }
    
    private func sendReset() {
        authVM.sendPasswordReset(email: resetEmail) { success, error in
            if success {
                ToastManager.shared.show("Reset link sent. Check your inbox (and spam folder).", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Couldn't send reset link", type: .error)
            }
        }
    }
}

#Preview {
    NavigationStack { LoginView() }.environmentObject(AuthViewModel())
}

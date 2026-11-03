import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var onSwitchToLogin: () -> Void = {}
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPrivacy = false
    
    init(onSwitchToLogin: @escaping () -> Void = {}) {
        self.onSwitchToLogin = onSwitchToLogin
    }
    
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    var passwordLongEnough: Bool { password.count >= 6 }
    var emailLooksValid: Bool { email.contains("@") && email.contains(".") }
    
    var isFormValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 50 && emailLooksValid && passwordLongEnough && passwordsMatch
    }
    
    /// 0...4 arası basit şifre gücü
    var strength: Int {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil
            || password.rangeOfCharacter(from: .punctuationCharacters) != nil
            || password.rangeOfCharacter(from: .symbols) != nil { score += 1 }
        return password.isEmpty ? 0 : max(score, 1)
    }
    
    var strengthLabel: String {
        switch strength {
        case 0: return ""
        case 1: return "Weak"
        case 2: return "Okay"
        case 3: return "Good"
        default: return "Strong"
        }
    }
    
    var strengthColor: Color {
        switch strength {
        case 0, 1: return AppTheme.coral
        case 2: return AppTheme.amber
        default: return AppTheme.mint
        }
    }
    
    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.7)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        .padding(.bottom, 28)
                    
                    heading
                        .padding(.bottom, 28)
                        .entrance(delay: 0.05)
                    
                    form
                        .entrance(delay: 0.15)
                    
                    footer
                        .padding(.top, 24)
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
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
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
            Text("Create your\naccount ✨")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Text("It takes less than a minute. Then create a house or join your roommates.")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var form: some View {
        VStack(spacing: 14) {
            AuthTextField(icon: "person.fill", placeholder: "Your name", text: $name,
                          contentType: .name)
            AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email,
                          keyboard: .emailAddress, contentType: .emailAddress)
            AuthTextField(icon: "lock.fill", placeholder: "Password", text: $password,
                          isSecure: true, contentType: .newPassword)
            
            if !password.isEmpty {
                strengthMeter
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            AuthTextField(icon: "lock.rotation", placeholder: "Confirm password", text: $confirmPassword,
                          isSecure: true, contentType: .newPassword, submitLabel: .done, onSubmit: submit)
            
            requirements
            
            if let error = authVM.errorMessage {
                AuthErrorBanner(message: error)
            }
            
            AuthPrimaryButton(title: "Create Account", isEnabled: isFormValid,
                              isLoading: authVM.isLoading, action: submit)
                .padding(.top, 6)
            
            Button(action: { showPrivacy = true }) {
                Text("By creating an account you agree to our **Privacy Policy**.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.25), value: password.isEmpty)
        .animation(.easeInOut(duration: 0.25), value: authVM.errorMessage)
    }
    
    private var strengthMeter: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < strength ? strengthColor : Color.white.opacity(0.1))
                        .frame(height: 5)
                }
            }
            Text(strengthLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(strengthColor)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .animation(.easeOut(duration: 0.2), value: strength)
    }
    
    private var requirements: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow("At least 6 characters", met: passwordLongEnough)
            requirementRow("Passwords match", met: passwordsMatch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(met ? AppTheme.mint : AppTheme.textMuted)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(met ? AppTheme.textSecondary : AppTheme.textMuted)
        }
        .animation(.easeOut(duration: 0.2), value: met)
    }
    
    private var footer: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Already have an account?")
                .foregroundColor(AppTheme.textSecondary)
            Button("Log in", action: onSwitchToLogin)
                .foregroundColor(AppTheme.mint)
                .fontWeight(.bold)
            Spacer()
        }
        .font(.system(size: 14))
    }
    
    // MARK: - Actions
    private func submit() {
        guard isFormValid, !authVM.isLoading else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        authVM.register(email: email, password: password, name: trimmedName)
    }
}

#Preview {
    NavigationStack { SignUpView() }.environmentObject(AuthViewModel())
}

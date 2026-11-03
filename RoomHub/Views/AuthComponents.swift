import SwiftUI

// MARK: - Animated aurora background
/// Yavaşça hareket eden, bulanık renk bulutlarından oluşan arka plan (giriş akışı için)
struct AuroraBackground: View {
    var intensity: Double = 1
    @State private var animate = false
    
    var body: some View {
        ZStack {
            AppTheme.background
            
            blob(color: AppTheme.mint, size: 340)
                .offset(x: animate ? -120 : -40, y: animate ? -260 : -180)
            blob(color: AppTheme.violet, size: 380)
                .offset(x: animate ? 140 : 60, y: animate ? -60 : 40)
            blob(color: AppTheme.coral, size: 260)
                .offset(x: animate ? -60 : -140, y: animate ? 300 : 220)
                .opacity(0.6)
            
            // Hafif karartma: metin okunabilirliği için
            LinearGradient(
                colors: [Color.black.opacity(0.0), AppTheme.background.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .accessibilityHidden(true)
    }
    
    private func blob(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.28 * intensity))
            .frame(width: size, height: size)
            .blur(radius: 90)
    }
}

// MARK: - Glowing logo
struct GlowingLogo: View {
    var size: CGFloat = 64
    @State private var glow = false
    
    var body: some View {
        Image("logopng")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .shadow(color: AppTheme.mint.opacity(glow ? 0.9 : 0.5), radius: glow ? 18 : 8)
            .shadow(color: AppTheme.mint.opacity(0.35), radius: 30)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Auth text field (ikonlu, odakta parlayan, şifre göster/gizle)
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboard: UIKeyboardType
    let contentType: UITextContentType?
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var isRevealed = false
    
    init(icon: String,
         placeholder: String,
         text: Binding<String>,
         isSecure: Bool = false,
         keyboard: UIKeyboardType = .default,
         contentType: UITextContentType? = nil,
         submitLabel: SubmitLabel = .next,
         onSubmit: @escaping () -> Void = {}) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboard = keyboard
        self.contentType = contentType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFocused ? AppTheme.mint : AppTheme.textMuted)
                .frame(width: 20)
            
            inputField
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .tint(AppTheme.mint)
                .focused($isFocused)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
            
            if isSecure {
                Button(action: { isRevealed.toggle() }) {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                }
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.09 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFocused ? AppTheme.mint.opacity(0.8) : AppTheme.cardGlassBorder,
                        lineWidth: isFocused ? 1.5 : 1)
        )
        .shadow(color: AppTheme.mint.opacity(isFocused ? 0.25 : 0), radius: 12)
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
    
    @ViewBuilder
    private var inputField: some View {
        if isSecure && !isRevealed {
            SecureField(placeholder, text: $text)
                .textContentType(contentType)
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(keyboard == .emailAddress || isSecure ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || isSecure)
        }
    }
}

// MARK: - Big gradient CTA button
struct AuthPrimaryButton: View {
    let title: String
    var icon: String = "arrow.right"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isEnabled ? AppTheme.mintGradient : AppTheme.disabledGradient)
            )
            .shadow(color: AppTheme.mint.opacity(isEnabled ? 0.35 : 0), radius: 16, y: 6)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(PressableButtonStyle())
    }
}

/// Basılınca hafifçe küçülen buton stili
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Round back button
struct AuthBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(AppTheme.cardGlassBorder, lineWidth: 1))
        }
        .accessibilityLabel("Back")
    }
}

// MARK: - Error banner
struct AuthErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(AppTheme.coral)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.coral.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.coral.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Staggered entrance animation
/// Görünürken aşağıdan yukarı kayarak beliren içerik (sırayla gecikmeli)
struct EntranceModifier: ViewModifier {
    let delay: Double
    @State private var visible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func entrance(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay))
    }
}

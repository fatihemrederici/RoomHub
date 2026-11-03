import SwiftUI
import Combine

// MARK: - Auth flow (Welcome → Login / Sign Up)
enum AuthRoute: Hashable {
    case login
    case signUp
}

struct AuthFlowView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var path: [AuthRoute] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onGetStarted: { path = [.signUp] },
                onLogin: { path = [.login] }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView(onSwitchToSignUp: { path = [.signUp] })
                case .signUp:
                    SignUpView(onSwitchToLogin: { path = [.login] })
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Feature pages
struct WelcomeFeature: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let glow: Color
    let chips: [WelcomeChip]
}

struct WelcomeChip: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
    let offset: CGSize
}

extension WelcomeFeature {
    static let all: [WelcomeFeature] = [
        WelcomeFeature(
            id: 0,
            icon: "creditcard.and.123",
            title: "Split bills,\nnot friendships",
            subtitle: "Log shared expenses in any currency and split them equally or by exact amounts.",
            gradient: AppTheme.mintGradient,
            glow: AppTheme.mint,
            chips: [
                WelcomeChip(icon: "house.fill", text: "Rent · split 3 ways", color: AppTheme.mint, offset: CGSize(width: -78, height: -92)),
                WelcomeChip(icon: "cart.fill", text: "Groceries · €42.60", color: AppTheme.amber, offset: CGSize(width: 84, height: 88))
            ]
        ),
        WelcomeFeature(
            id: 1,
            icon: "arrow.left.arrow.right",
            title: "Settle up\nin seconds",
            subtitle: "RoomHub works out who owes whom — with the fewest payments possible.",
            gradient: AppTheme.violetGradient,
            glow: AppTheme.violet,
            chips: [
                WelcomeChip(icon: "arrow.down.left.circle.fill", text: "Alex owes you €18", color: AppTheme.mint, offset: CGSize(width: 74, height: -92)),
                WelcomeChip(icon: "checkmark.seal.fill", text: "All settled up!", color: AppTheme.violet, offset: CGSize(width: -80, height: 90))
            ]
        ),
        WelcomeFeature(
            id: 2,
            icon: "checklist",
            title: "Chores on\nautopilot",
            subtitle: "Assign tasks, set them to repeat and never argue about the trash again.",
            gradient: AppTheme.amberGradient,
            glow: AppTheme.amber,
            chips: [
                WelcomeChip(icon: "repeat", text: "Trash · every week", color: AppTheme.amber, offset: CGSize(width: -82, height: -90)),
                WelcomeChip(icon: "sparkles", text: "Kitchen done ✓", color: AppTheme.mint, offset: CGSize(width: 80, height: 92))
            ]
        ),
        WelcomeFeature(
            id: 3,
            icon: "person.3.fill",
            title: "One home,\none app",
            subtitle: "Invite roommates with a 6-character code. Everything syncs live for everyone.",
            gradient: LinearGradient(colors: [AppTheme.coral, AppTheme.violet], startPoint: .topLeading, endPoint: .bottomTrailing),
            glow: AppTheme.coral,
            chips: [
                WelcomeChip(icon: "key.fill", text: "Code: K7M2QX", color: AppTheme.coral, offset: CGSize(width: 78, height: -92)),
                WelcomeChip(icon: "bolt.fill", text: "Live sync", color: AppTheme.mint, offset: CGSize(width: -76, height: 90))
            ]
        )
    ]
}

// MARK: - Welcome screen
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onLogin: () -> Void
    
    @State private var page = 0
    @State private var userInteracted = false
    private let timer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()
    private let features = WelcomeFeature.all
    
    init(onGetStarted: @escaping () -> Void, onLogin: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
        self.onLogin = onLogin
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
            
            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .entrance(delay: 0.05)
                
                carousel
                    .entrance(delay: 0.15)
                
                pageIndicator
                    .padding(.bottom, 28)
                    .entrance(delay: 0.25)
                
                actions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .entrance(delay: 0.35)
            }
        }
        .navigationBarHidden(true)
        .onReceive(timer) { _ in
            guard !userInteracted else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                page = (page + 1) % features.count
            }
        }
    }
    
    // MARK: Parts
    private var header: some View {
        HStack(spacing: 10) {
            GlowingLogo(size: 34)
            Text("RoomHub")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Button("Log in", action: onLogin)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 24)
    }
    
    private var carousel: some View {
        TabView(selection: $page) {
            ForEach(features) { feature in
                WelcomeFeaturePage(feature: feature, isActive: page == feature.id)
                    .tag(feature.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .simultaneousGesture(DragGesture().onChanged { _ in userInteracted = true })
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(features) { feature in
                Capsule()
                    .fill(page == feature.id ? AppTheme.mint : Color.white.opacity(0.2))
                    .frame(width: page == feature.id ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
                    .onTapGesture {
                        userInteracted = true
                        withAnimation { page = feature.id }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(features.count)")
    }
    
    private var actions: some View {
        VStack(spacing: 14) {
            AuthPrimaryButton(title: "Get Started", action: onGetStarted)
            
            Button(action: onLogin) {
                Text("I already have an account")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Single feature page
struct WelcomeFeaturePage: View {
    let feature: WelcomeFeature
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            
            WelcomeIllustration(feature: feature, isActive: isActive)
                .frame(height: 280)
            
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.8)
                
                Text(feature.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(isActive ? 1 : 0.3)
            .offset(y: isActive ? 0 : 12)
            .animation(.easeOut(duration: 0.5), value: isActive)
            
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Animated illustration
struct WelcomeIllustration: View {
    let feature: WelcomeFeature
    let isActive: Bool
    
    @State private var float = false
    @State private var spin = false
    
    var body: some View {
        ZStack {
            // Dönen dış halka
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [feature.glow.opacity(0), feature.glow.opacity(0.8), feature.glow.opacity(0)],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 230, height: 230)
                .rotationEffect(.degrees(spin ? 360 : 0))
            
            // İç cam halka
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 180, height: 180)
                .overlay(Circle().stroke(AppTheme.cardGlassBorder, lineWidth: 1))
            
            // Ana ikon
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(feature.gradient)
                    .frame(width: 116, height: 116)
                    .shadow(color: feature.glow.opacity(0.55), radius: 30, y: 10)
                Image(systemName: feature.icon)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, value: isActive)
            }
            .scaleEffect(isActive ? 1 : 0.8)
            .rotationEffect(.degrees(isActive ? 0 : -8))
            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: isActive)
            
            // Yüzen bilgi kartları
            ForEach(Array(feature.chips.enumerated()), id: \.element.id) { index, chip in
                WelcomeChipView(chip: chip)
                    .offset(x: chip.offset.width,
                            y: chip.offset.height + (float ? (index == 0 ? -6 : 6) : 0))
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.7)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(isActive ? 0.15 + Double(index) * 0.1 : 0),
                               value: isActive)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                float = true
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct WelcomeChipView: View {
    let chip: WelcomeChip
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(chip.color)
            Text(chip.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

#Preview {
    AuthFlowView().environmentObject(AuthViewModel())
}

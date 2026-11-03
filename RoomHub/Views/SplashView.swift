import SwiftUI

struct SplashView: View {
    @State private var pulse = false
    @State private var rotate = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.85
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            // Arka planda yavaşça dönen ambient glow
            Circle()
                .fill(AppTheme.mint.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .scaleEffect(pulse ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)
            
            VStack(spacing: 24) {
                ZStack {
                    // Dönen dış halka
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [AppTheme.mint.opacity(0), AppTheme.mint, AppTheme.mint.opacity(0)],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(rotate ? 360 : 0))
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: rotate)
                    
                    Image("logopng")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                        .shadow(color: AppTheme.mint.opacity(0.8), radius: 4)
                        .shadow(color: AppTheme.mint.opacity(0.5), radius: 14)
                        .shadow(color: AppTheme.mint.opacity(0.3), radius: 28)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            pulse = true
            rotate = true
        }
    }
}

#Preview {
    SplashView()
}

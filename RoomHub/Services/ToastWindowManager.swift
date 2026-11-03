import SwiftUI
import UIKit
import Combine

class ToastWindowManager {
    static let shared = ToastWindowManager()
    
    private var window: UIWindow?
    private var cancellable: AnyCancellable?
    
    private init() {
        cancellable = ToastManager.shared.$currentToast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] toast in
                self?.updateWindow(toast: toast)
            }
    }
    
    private func updateWindow(toast: ToastMessage?) {
        guard let toast = toast else {
            window?.isHidden = true
            window = nil
            return
        }
        
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        
        let hostingController = UIHostingController(
            rootView: VStack {
                ToastView(toast: toast)
                    .padding(.top, 8)
                Spacer()
            }
                .ignoresSafeArea(edges: .bottom)
        )
        hostingController.view.backgroundColor = .clear
        
        let newWindow = UIWindow(windowScene: scene)
        newWindow.rootViewController = hostingController
        newWindow.windowLevel = .alert + 1   // sheet, alert, her şeyin üstünde
        newWindow.backgroundColor = .clear
        newWindow.isUserInteractionEnabled = false   // dokunuşları alttaki ekrana geçirir
        newWindow.isHidden = false
        
        self.window = newWindow
    }
}

import SwiftUI
import Combine

enum ToastType {
    case error
    case success
    case info
    
    var color: Color {
        switch self {
        case .error: return AppTheme.coral
        case .success: return AppTheme.mint
        case .info: return AppTheme.violet
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastMessage?
    
    private init() {}
    
    func show(_ message: String, type: ToastType = .error) {
        guard !message.isEmpty else { return }
        DispatchQueue.main.async {
            let toast = ToastMessage(message: message, type: type)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.currentToast = toast
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    // Sadece bu toast hâlâ ekrandaysa kapat (aynı mesaj art arda gelince erken kapanmasın)
                    if self.currentToast?.id == toast.id {
                        self.currentToast = nil
                    }
                }
            }
        }
    }
}

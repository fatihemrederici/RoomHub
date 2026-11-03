import SwiftUI

struct ToastView: View {
    let toast: ToastMessage
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 15, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(3)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toast.type.color)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

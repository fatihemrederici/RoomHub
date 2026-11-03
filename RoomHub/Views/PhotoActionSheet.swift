import SwiftUI

struct PhotoActionSheet: View {
    let hasPhoto: Bool
    let onChoosePhoto: () -> Void
    let onRemovePhoto: () -> Void
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("Profile Photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 8)
                
                Button(action: onChoosePhoto) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text("Choose Photo")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.mintGradient)
                    .cornerRadius(14)
                }
                
                if hasPhoto {
                    Button(action: onRemovePhoto) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Remove Photo")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppTheme.coral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.coral.opacity(0.1))
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

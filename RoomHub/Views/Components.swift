import SwiftUI

// MARK: - Avatar (fotoğraf ya da baş harf)
struct AvatarView: View {
    let name: String
    var photoBase64: String? = nil
    var size: CGFloat = 40
    var color: Color = AppTheme.mint
    
    var body: some View {
        ZStack {
            if let image = ImageProcessor.image(fromBase64: photoBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: size, height: size)
                Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Section header ("ACTIVITY", "TITLE" ...)
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textMuted)
            .padding(.leading, 4)
    }
}

// MARK: - Empty state
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textMuted)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Primary button
struct PrimaryButton: View {
    let title: String
    var gradient: LinearGradient = AppTheme.mintGradient
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? gradient : AppTheme.disabledGradient)
            .cornerRadius(16)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Themed text field
struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalize: Bool = true
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(contentType)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                    .autocorrectionDisabled(!autocapitalize)
            }
        }
        .font(.system(size: 16))
        .foregroundColor(AppTheme.textPrimary)
        .padding(14)
        .glassCard()
    }
}

// MARK: - Currency chip button
struct CurrencyChip: View {
    let currency: Currency
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(currency.flag)
                Text(currency.code)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
        }
        .accessibilityLabel("Currency: \(currency.name)")
    }
}

// MARK: - Selectable member row (çoklu seçim)
struct SelectableMemberRow: View {
    let user: AppUser
    let isYou: Bool
    let isSelected: Bool
    var tint: Color = AppTheme.mint
    var trailingText: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AvatarView(name: user.name, photoBase64: user.photoBase64, size: 36, color: tint)
                Text(isYou ? "\(user.name) (You)" : user.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let trailingText = trailingText {
                    Text(trailingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                SelectionCircle(isSelected: isSelected, tint: tint)
            }
            .padding(12)
            .glassCard()
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SelectionCircle: View {
    let isSelected: Bool
    var tint: Color = AppTheme.mint
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? tint : AppTheme.textMuted, lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle().fill(tint).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Segmented pill picker (tema uyumlu)
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    var tint: Color = AppTheme.violet
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    Text(label(option))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == option ? .white : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == option ? tint : Color.white.opacity(0.06))
                        .cornerRadius(12)
                }
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}

// MARK: - Offline / rates warning banner
struct InfoBanner: View {
    let icon: String
    let text: String
    var color: Color = AppTheme.amber
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(color)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Amount text parsing
enum AmountParser {
    /// "12,50" ve "12.50" kabul edilir; en fazla 2 ondalık (ya da para birimi ondalıksızsa 0)
    static func parse(_ text: String, currency: Currency) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return currency.rounded(value)
    }
    
    /// Kullanıcının yazdığı metni temizler: tek ayraç, en fazla 2 ondalık
    static func sanitize(_ text: String, allowDecimals: Bool = true) -> String {
        var result = ""
        var hasSeparator = false
        var decimals = 0
        for char in text {
            if char.isNumber {
                if hasSeparator {
                    guard decimals < 2 else { continue }
                    decimals += 1
                }
                result.append(char)
            } else if (char == "," || char == "."), allowDecimals, !hasSeparator {
                hasSeparator = true
                result.append(char)
            }
        }
        return String(result.prefix(12))
    }
    
    static func editingString(for value: Double, currency: Currency) -> String {
        if !currency.usesDecimals || value.rounded() == value {
            return String(Int(value.rounded()))
        }
        let separator = Locale.current.decimalSeparator ?? "."
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: separator)
    }
}

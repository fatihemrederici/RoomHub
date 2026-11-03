import Foundation

/// Firebase'in ham hata mesajlarını kullanıcı dostu metinlere çevirir.
/// (Kod numaraları Firebase'in herkese açık hata kodlarıdır.)
enum FriendlyError {
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17007: return "This email is already registered. Try logging in instead."
            case 17008: return "Please enter a valid email address."
            case 17009, 17004: return "Incorrect email or password."
            case 17011: return "No account found with this email."
            case 17026: return "Password must be at least 6 characters."
            case 17010: return "Too many attempts. Please wait a moment and try again."
            case 17020: return "No internet connection. Please try again."
            case 17005: return "This account has been disabled."
            case 17014: return "For security, please log out and log back in, then try again."
            default: break
            }
        }
        
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: return "You don't have permission to do that."
            case 14: return "You're offline. Changes will sync when you're back online."
            case 5: return "This item no longer exists."
            default: break
            }
        }
        
        if nsError.domain == NSURLErrorDomain {
            return "No internet connection. Please try again."
        }
        
        return error.localizedDescription
    }
    
    static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7
    }
}

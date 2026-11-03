import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var houseId: String?
    var photoBase64: String? = nil
    var createdAt: Date = Date()
}

extension AppUser {
    /// Eksik alanlı eski dokümanları da okuyabilmek için toleranslı çözümleme
    static func from(_ doc: DocumentSnapshot) -> AppUser? {
        if let user = try? doc.data(as: AppUser.self) {
            return user
        }
        guard doc.exists, let data = doc.data() else { return nil }
        let email = data["email"] as? String ?? ""
        let fallbackName = email.split(separator: "@").first.map(String.init) ?? "User"
        return AppUser(
            id: doc.documentID,
            name: (data["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName,
            email: email,
            houseId: data["houseId"] as? String,
            photoBase64: data["photoBase64"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }
}

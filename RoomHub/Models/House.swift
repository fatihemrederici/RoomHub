import Foundation
import FirebaseFirestore

struct House: Identifiable, Codable {
    @DocumentID var id: String?
    var houseName: String
    var createdBy: String
    var members: [String]
    var admins: [String]? = nil          // Optional: eski dokümanlarda olmayabilir
    var inviteCode: String
    var imageBase64: String? = nil
    var currencyCode: String? = nil      // Evin ana para birimi (bakiyeler bununla tutulur)
    var createdAt: Date? = nil
    var pastMembers: [String: String]? = nil   // Ayrılan üyelerin isimleri (uid → isim)
    
    var adminList: [String] {
        admins ?? []
    }
    
    func isOwner(_ userId: String) -> Bool {
        createdBy == userId
    }
    
    func isAdmin(_ userId: String) -> Bool {
        createdBy == userId || adminList.contains(userId)
    }
}

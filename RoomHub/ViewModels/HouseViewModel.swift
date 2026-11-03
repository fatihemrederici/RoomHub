import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Ev kurulumu: yeni ev oluşturma ve davet koduyla katılma
class HouseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebase = FirebaseService.shared
    private var db: Firestore { firebase.db }
    
    /// 6 haneli kod; karışan karakterler (0/O, 1/I) çıkarıldı (~1 milyar kombinasyon)
    static func generateInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Create House
    /// Ev, davet kodu ve kullanıcının houseId'si tek bir atomik işlemde yazılır
    func createHouse(name: String, currencyCode: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, "You're not signed in.")
            return
        }
        isLoading = true
        attemptCreate(uid: uid, name: name, currencyCode: currencyCode, attempt: 0, completion: completion)
    }
    
    private func attemptCreate(uid: String, name: String, currencyCode: String, attempt: Int,
                               completion: @escaping (Bool, String?) -> Void) {
        let inviteCode = HouseViewModel.generateInviteCode()
        let houseRef = firebase.houses.document()
        
        let houseData: [String: Any] = [
            "houseName": name,
            "createdBy": uid,
            "members": [uid],
            "admins": [String](),
            "inviteCode": inviteCode,
            "currencyCode": currencyCode,
            "createdAt": Timestamp(date: Date())
        ]
        
        let batch = db.batch()
        batch.setData(houseData, forDocument: houseRef)
        batch.setData([
            "houseId": houseRef.documentID,
            "createdBy": uid,
            "createdAt": Timestamp(date: Date())
        ], forDocument: firebase.invites.document(inviteCode))
        batch.updateData(["houseId": houseRef.documentID], forDocument: firebase.users.document(uid))
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    // Kod çakışması (çok düşük ihtimal) → yeni kodla tekrar dene
                    if attempt < 2 && FriendlyError.isPermissionDenied(error) {
                        self.attemptCreate(uid: uid, name: name, currencyCode: currencyCode,
                                           attempt: attempt + 1, completion: completion)
                        return
                    }
                    self.isLoading = false
                    completion(false, FriendlyError.message(for: error))
                } else {
                    self.isLoading = false
                    completion(true, inviteCode)
                }
            }
        }
    }
    
    // MARK: - Join House
    func joinHouse(inviteCode: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, "You're not signed in.")
            return
        }
        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6 else {
            completion(false, "Invite codes are 6 characters long.")
            return
        }
        isLoading = true
        
        firebase.invites.document(code).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, FriendlyError.message(for: error))
                }
                return
            }
            guard let houseId = snapshot?.data()?["houseId"] as? String else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, "Invalid invite code. Ask your roommate for the latest code.")
                }
                return
            }
            
            let batch = self.db.batch()
            batch.updateData([
                "members": FieldValue.arrayUnion([uid]),
                "lastJoin": ["uid": uid, "code": code]
            ], forDocument: self.firebase.houses.document(houseId))
            batch.updateData(["houseId": houseId], forDocument: self.firebase.users.document(uid))
            
            batch.commit { error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        if FriendlyError.isPermissionDenied(error) {
                            completion(false, "This invite code is no longer valid or the house is full.")
                        } else {
                            completion(false, FriendlyError.message(for: error))
                        }
                    } else {
                        completion(true, nil)
                    }
                }
            }
        }
    }
}

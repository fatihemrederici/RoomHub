import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Firebase'e tek giriş noktası. Ücretli hiçbir Firebase özelliği (Storage, Functions vb.)
/// kullanılmaz; her şey ücretsiz Spark planındaki Auth + Firestore ile çalışır.
final class FirebaseService {
    static let shared = FirebaseService()
    
    let db: Firestore
    
    private init() {
        FirebaseService.configureIfNeeded()
        db = Firestore.firestore()
    }
    
    /// Uygulama, Xcode önizlemeleri ve testlerde tekrar tekrar çağrılabilir
    static func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    // MARK: - Collections
    var users: CollectionReference { db.collection("users") }
    var houses: CollectionReference { db.collection("houses") }
    var invites: CollectionReference { db.collection("invites") }
    
    func expenses(_ houseId: String) -> CollectionReference {
        houses.document(houseId).collection("expenses")
    }
    func settlements(_ houseId: String) -> CollectionReference {
        houses.document(houseId).collection("settlements")
    }
    func chores(_ houseId: String) -> CollectionReference {
        houses.document(houseId).collection("chores")
    }
    
    // MARK: - Register (Sign Up)
    func register(email: String, password: String, name: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(false, FriendlyError.message(for: error))
                return
            }
            guard let self = self, let authUser = result?.user else {
                completion(false, "Something went wrong. Please try again.")
                return
            }
            
            // Doğrulama e-postası (ücretsiz) — uygulamayı kullanmak için zorunlu değil
            authUser.sendEmailVerification(completion: nil)
            
            self.createUserDocument(uid: authUser.uid, name: name, email: email) { success, error in
                completion(success, error)
            }
        }
    }
    
    /// Kullanıcı dokümanını oluşturur (kayıtta ya da yarım kalmış eski hesaplarda)
    func createUserDocument(uid: String, name: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? (email.split(separator: "@").first.map(String.init) ?? "User") : trimmed
        let data: [String: Any] = [
            "name": String(safeName.prefix(50)),
            "email": email,
            "createdAt": Timestamp(date: Date())
        ]
        users.document(uid).setData(data) { error in
            if let error = error {
                print("🔴 Create user doc error: \(error.localizedDescription)")
            }
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    // MARK: - Login / Logout / Password
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func logout() throws {
        try Auth.auth().signOut()
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func reauthenticate(password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            completion(false, "You're not signed in.")
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { _, error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func changePassword(current: String, new newPassword: String, completion: @escaping (Bool, String?) -> Void) {
        reauthenticate(password: current) { success, error in
            guard success, let user = Auth.auth().currentUser else {
                completion(false, error)
                return
            }
            user.updatePassword(to: newPassword) { error in
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    // MARK: - Profile
    func updateUserName(userId: String, newName: String, completion: @escaping (Bool, String?) -> Void) {
        users.document(userId).updateData(["name": newName]) { error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func updateUserPhoto(userId: String, imageData: Data, completion: @escaping (Bool, String?) -> Void) {
        users.document(userId).updateData([
            "photoBase64": imageData.base64EncodedString()
        ]) { error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func removeUserPhoto(userId: String, completion: @escaping (Bool, String?) -> Void) {
        users.document(userId).updateData([
            "photoBase64": FieldValue.delete()
        ]) { error in
            completion(error == nil, error.map { FriendlyError.message(for: $0) })
        }
    }
    
    func clearHouseId(userId: String, completion: ((Bool) -> Void)? = nil) {
        users.document(userId).updateData(["houseId": FieldValue.delete()]) { error in
            if let error = error {
                print("🔴 clearHouseId error: \(error.localizedDescription)")
            }
            completion?(error == nil)
        }
    }
    
    // MARK: - Delete Account
    /// Kullanıcı dokümanını ve Auth hesabını siler. Evden ayrılma işlemi önce yapılmalıdır.
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, "You're not signed in.")
            return
        }
        users.document(user.uid).delete { error in
            if let error = error {
                completion(false, FriendlyError.message(for: error))
                return
            }
            user.delete { error in
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
}

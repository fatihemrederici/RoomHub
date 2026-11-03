import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCheckingAuth = true
    
    /// Ev oluşturulduktan sonra davet kodu gösterilirken ana ekrana geçişi bekletir
    @Published var holdHouseSetup = false
    
    let firebase = FirebaseService.shared
    private var db: Firestore { firebase.db }
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let listeners = ListenerBag()
    private var listeningUid: String?
    private var observedHouseId: String?
    private var isRegistering = false
    private var isCreatingMissingDoc = false
    
    init() {
        // Oturum durumunu tek kaynaktan takip et: giriş, çıkış, hesap kapatılması vb.
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.handleAuthChange(user)
            }
        }
    }
    
    private func handleAuthChange(_ user: User?) {
        if let user = user {
            isLoggedIn = true
            startListening(uid: user.uid)
        } else {
            stopListening()
            isLoggedIn = false
            currentUser = nil
            holdHouseSetup = false
            isCheckingAuth = false
        }
    }
    
    /// Eski çağrılarla uyumluluk için; dinleyici zaten her şeyi güncel tutar
    func checkAuthStatus() {
        handleAuthChange(Auth.auth().currentUser)
    }
    
    // MARK: - Live listeners
    private func startListening(uid: String) {
        if listeners.has("user") && listeningUid == uid { return }
        stopListening()
        listeningUid = uid
        isCheckingAuth = true
        
        let listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 User listener error: \(error.localizedDescription)")
                self.isCheckingAuth = false
                return
            }
            guard let snapshot = snapshot else { return }
            
            if !snapshot.exists {
                // Kayıt yarım kalmışsa (Auth hesabı var ama doküman yok) dokümanı oluştur
                if !snapshot.metadata.isFromCache && !self.isRegistering {
                    self.createMissingUserDocument(uid: uid)
                }
                if !snapshot.metadata.isFromCache {
                    self.currentUser = nil
                    self.isCheckingAuth = self.isRegistering || self.isCreatingMissingDoc
                }
                return
            }
            
            let user = AppUser.from(snapshot)
            self.currentUser = user
            self.isCheckingAuth = false
            self.observeHouse(houseId: user?.houseId, uid: uid)
        }
        listeners.set("user", listener)
    }
    
    private func createMissingUserDocument(uid: String) {
        guard !isCreatingMissingDoc, let authUser = Auth.auth().currentUser, authUser.uid == uid else { return }
        isCreatingMissingDoc = true
        let email = authUser.email ?? ""
        let name = authUser.displayName ?? ""
        firebase.createUserDocument(uid: uid, name: name, email: email) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isCreatingMissingDoc = false
                self?.isCheckingAuth = false
            }
        }
    }
    
    /// Ev silindiyse ya da kullanıcı üyelikten çıkarıldıysa houseId'yi temizler
    private func observeHouse(houseId: String?, uid: String) {
        guard houseId != observedHouseId else { return }
        listeners.remove("house")
        observedHouseId = houseId
        guard let houseId = houseId else { return }
        
        let listener = db.collection("houses").document(houseId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                // Üye değilsek kurallar okumayı reddeder → evden çıkarılmışız ya da ev silinmiş
                if FriendlyError.isPermissionDenied(error) {
                    self.clearOwnHouseId(uid: uid, expectedHouseId: houseId)
                } else {
                    print("🔴 House listener error: \(error.localizedDescription)")
                }
                return
            }
            guard let snapshot = snapshot,
                  !snapshot.metadata.isFromCache,
                  !snapshot.metadata.hasPendingWrites else { return }
            
            let members = snapshot.data()?["members"] as? [String] ?? []
            if !snapshot.exists || !members.contains(uid) {
                self.clearOwnHouseId(uid: uid, expectedHouseId: houseId)
            }
        }
        listeners.set("house", listener)
    }
    
    private func clearOwnHouseId(uid: String, expectedHouseId: String) {
        guard currentUser?.houseId == expectedHouseId else { return }
        firebase.clearHouseId(userId: uid)
    }
    
    func stopListening() {
        listeners.removeAll()
        listeningUid = nil
        observedHouseId = nil
    }
    
    // MARK: - Auth
    func register(email: String, password: String, name: String) {
        errorMessage = nil
        isLoading = true
        isRegistering = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        firebase.register(email: cleanEmail, password: password, name: cleanName) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.isRegistering = false
                if success {
                    self.isCheckingAuth = false
                    ToastManager.shared.show("Welcome! We sent a verification email to \(cleanEmail).", type: .success)
                } else {
                    self.errorMessage = error
                    // Auth hesabı oluştu ama doküman yazılamadıysa dinleyici eksik dokümanı tamamlar
                    if let uid = Auth.auth().currentUser?.uid {
                        self.createMissingUserDocument(uid: uid)
                    }
                }
            }
        }
    }
    
    func login(email: String, password: String) {
        errorMessage = nil
        isLoading = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        firebase.login(email: cleanEmail, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if !success {
                    self.errorMessage = error
                }
                // Başarılı girişte oturum dinleyicisi ekranı otomatik değiştirir
            }
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            completion(false, "Please enter your email address.")
            return
        }
        firebase.sendPasswordReset(email: cleanEmail) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func changePassword(current: String, new newPassword: String, completion: @escaping (Bool, String?) -> Void) {
        firebase.changePassword(current: current, new: newPassword) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func logout() {
        stopListening()
        try? firebase.logout()
        isLoggedIn = false
        currentUser = nil
        holdHouseSetup = false
    }
    
    // MARK: - Profile
    func updateName(_ newName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = currentUser?.id else {
            completion(false, "You're not signed in.")
            return
        }
        firebase.updateUserName(userId: uid, newName: newName) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func updatePhoto(imageData: Data, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = currentUser?.id else {
            completion(false, "You're not signed in.")
            return
        }
        firebase.updateUserPhoto(userId: uid, imageData: imageData) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func removePhoto(completion: @escaping (Bool, String?) -> Void) {
        guard let uid = currentUser?.id else {
            completion(false, "You're not signed in.")
            return
        }
        firebase.removeUserPhoto(userId: uid) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    // MARK: - Delete Account
    func reauthenticate(password: String, completion: @escaping (Bool, String?) -> Void) {
        firebase.reauthenticate(password: password) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    /// Evden ayrıldıktan sonra çağrılır: kullanıcı dokümanını ve Auth hesabını siler
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        stopListening()
        firebase.deleteAccount { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.isLoggedIn = false
                    self.currentUser = nil
                    self.holdHouseSetup = false
                } else if let uid = Auth.auth().currentUser?.uid {
                    self.startListening(uid: uid)
                }
                completion(success, error)
            }
        }
    }
}

import Foundation
import FirebaseFirestore

/// Firestore dinleyicilerini tutar; sahibi (ViewModel/Store) serbest kalınca hepsini kapatır.
/// Ayrı, aktöre bağlı olmayan bir sınıf olduğu için deinit'te güvenle temizlenebilir.
nonisolated final class ListenerBag: @unchecked Sendable {
    private var listeners: [String: ListenerRegistration] = [:]
    private let lock = NSLock()
    
    func set(_ key: String, _ listener: ListenerRegistration?) {
        lock.lock()
        let old = listeners[key]
        listeners[key] = listener
        lock.unlock()
        old?.remove()
    }
    
    func remove(_ key: String) {
        set(key, nil)
    }
    
    func has(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return listeners[key] != nil
    }
    
    func keys(withPrefix prefix: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return listeners.keys.filter { $0.hasPrefix(prefix) }
    }
    
    func removeAll() {
        lock.lock()
        let all = listeners
        listeners.removeAll()
        lock.unlock()
        all.values.forEach { $0.remove() }
    }
    
    deinit {
        listeners.values.forEach { $0.remove() }
    }
}

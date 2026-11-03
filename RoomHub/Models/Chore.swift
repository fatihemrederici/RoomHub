import Foundation
import FirebaseFirestore

struct Chore: Identifiable, Codable {
    @DocumentID var id: String?
    var houseId: String
    var title: String
    var assignedTo: [String] = []
    var dueDate: Date = Date()
    var frequency: String = "one-time"
    var completed: Bool = false
    var completedAt: Date? = nil
    var createdBy: String
    var createdAt: Date = Date()
    var completedBy: String? = nil
    
    var isRecurring: Bool { frequency != ChoreFrequency.oneTime.rawValue }
    
    /// Bugünden önceki bir güne ait ve hâlâ tamamlanmamışsa gecikmiştir
    var isOverdue: Bool {
        !completed && dueDate < Calendar.current.startOfDay(for: Date())
    }
    
    var isDueToday: Bool {
        !completed && Calendar.current.isDateInToday(dueDate)
    }
}

enum ChoreFrequency: String, CaseIterable, Identifiable {
    case oneTime = "one-time"
    case daily
    case weekly
    case monthly
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .oneTime: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    /// Verilen tarihten bir sonraki tekrar tarihi
    func next(after date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .oneTime: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}

// MARK: - Tolerant decoding (eski / eksik alanlı dokümanlar için)
extension Chore {
    static func from(_ doc: DocumentSnapshot) -> Chore? {
        if let chore = try? doc.data(as: Chore.self) {
            return chore
        }
        guard let data = doc.data(),
              let houseId = data["houseId"] as? String,
              let title = data["title"] as? String else {
            print("🔴 Could not decode chore \(doc.documentID)")
            return nil
        }
        
        var assignedTo: [String] = []
        if let list = data["assignedTo"] as? [String] {
            assignedTo = list
        } else if let single = data["assignedTo"] as? String, !single.isEmpty {
            assignedTo = [single]
        }
        
        return Chore(
            id: doc.documentID,
            houseId: houseId,
            title: title,
            assignedTo: assignedTo,
            dueDate: (data["dueDate"] as? Timestamp)?.dateValue() ?? Date(),
            frequency: data["frequency"] as? String ?? "one-time",
            completed: data["completed"] as? Bool ?? false,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            completedBy: data["completedBy"] as? String
        )
    }
}

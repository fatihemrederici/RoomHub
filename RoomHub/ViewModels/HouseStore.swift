import SwiftUI
import Combine
import FirebaseFirestore

/// Bir evin tüm canlı verisini (ev, üyeler, harcamalar, ödeşmeler, görevler) tek yerde tutar.
/// Bütün sekmeler aynı store'u paylaşır; böylece her ekran aynı veriyi gösterir,
/// değişiklikler anında her yere yansır ve gereksiz tekrar okuma yapılmaz.
final class HouseStore: ObservableObject {
    typealias Completion = (Bool, String?) -> Void
    
    let houseId: String
    let currentUserId: String
    
    @Published private(set) var house: House?
    @Published private(set) var members: [String: AppUser] = [:]
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var settlements: [Settlement] = []
    @Published private(set) var chores: [Chore] = []
    
    @Published private(set) var isLoadingHouse = true
    @Published private(set) var isLoadingExpenses = true
    @Published private(set) var isLoadingSettlements = true
    @Published private(set) var isLoadingChores = true
    
    private let firebase = FirebaseService.shared
    private var db: Firestore { firebase.db }
    private let rates = ExchangeRateService.shared
    private let listeners = ListenerBag()
    private var rateCancellable: AnyCancellable?
    private var didAttemptMigration = false
    private var didEnsureInvite = false
    
    init(houseId: String, currentUserId: String) {
        self.houseId = houseId
        self.currentUserId = currentUserId
        start()
        // Kurlar güncellenince bakiye/toplamları yeniden hesaplat
        rateCancellable = rates.$rates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
        rates.fetchRatesIfNeeded()
    }
    
    // MARK: - Listeners
    private func start() {
        let houseListener = firebase.houses.document(houseId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 House listener error: \(error.localizedDescription)")
                self.isLoadingHouse = false
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                self.isLoadingHouse = false
                return
            }
            do {
                let house = try snapshot.data(as: House.self)
                self.house = house
                self.syncMemberListeners(house.members)
                self.ensureInviteExists(for: house)
                self.migrateLegacyDataIfNeeded()
            } catch {
                print("🔴 House decode error: \(error)")
            }
            self.isLoadingHouse = false
        }
        listeners.set("house", houseListener)
        
        let expenseListener = firebase.expenses(houseId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 Expenses listener error: \(error.localizedDescription)")
            }
            if let snapshot = snapshot {
                self.expenses = snapshot.documents
                    .compactMap { Expense.from($0) }
                    .sorted { $0.date != $1.date ? $0.date > $1.date : $0.createdAt > $1.createdAt }
            }
            self.isLoadingExpenses = false
        }
        listeners.set("expenses", expenseListener)
        
        let settlementListener = firebase.settlements(houseId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 Settlements listener error: \(error.localizedDescription)")
            }
            if let snapshot = snapshot {
                self.settlements = snapshot.documents
                    .compactMap { Settlement.from($0) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
            self.isLoadingSettlements = false
        }
        listeners.set("settlements", settlementListener)
        
        let choreListener = firebase.chores(houseId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 Chores listener error: \(error.localizedDescription)")
            }
            if let snapshot = snapshot {
                self.chores = snapshot.documents
                    .compactMap { Chore.from($0) }
                    .sorted { a, b in
                        if a.completed != b.completed { return !a.completed }
                        if a.completed {
                            return (a.completedAt ?? a.dueDate) > (b.completedAt ?? b.dueDate)
                        }
                        return a.dueDate < b.dueDate
                    }
            }
            self.isLoadingChores = false
        }
        listeners.set("chores", choreListener)
    }
    
    /// Her üyenin profilini canlı dinler (isim / foto değişiklikleri anında görünür)
    private func syncMemberListeners(_ memberIds: [String]) {
        let wanted = Set(memberIds)
        let prefix = "member:"
        
        for key in listeners.keys(withPrefix: prefix) {
            let uid = String(key.dropFirst(prefix.count))
            if !wanted.contains(uid) {
                listeners.remove(key)
                members[uid] = nil
            }
        }
        
        for uid in wanted where !listeners.has(prefix + uid) {
            let listener = firebase.users.document(uid).addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ Member \(uid) not readable: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot, let user = AppUser.from(snapshot) {
                    self.members[uid] = user
                }
            }
            listeners.set(prefix + uid, listener)
        }
    }
    
    func stop() {
        listeners.removeAll()
    }
    
    // MARK: - Members & roles
    var memberIds: [String] { house?.members ?? [] }
    
    /// Ev listesindeki sırayla, siz en başta
    var memberList: [AppUser] {
        let ordered = memberIds.compactMap { members[$0] }
        return ordered.sorted { a, _ in a.id == currentUserId }
    }
    
    var currentUser: AppUser? { members[currentUserId] }
    var isAdmin: Bool { house?.isAdmin(currentUserId) ?? false }
    var isOwner: Bool { house?.isOwner(currentUserId) ?? false }
    
    func user(_ uid: String) -> AppUser? { members[uid] }
    
    /// "You" ya da üyenin adı
    func name(for uid: String) -> String {
        uid == currentUserId ? "You" : fullName(for: uid)
    }
    
    func fullName(for uid: String) -> String {
        if let user = members[uid] { return user.name }
        if let past = house?.pastMembers?[uid] { return past }
        return memberIds.contains(uid) ? "Member" : "Former member"
    }
    
    func isCurrentMember(_ uid: String) -> Bool { memberIds.contains(uid) }
    
    // MARK: - Currency
    /// Evin ana para birimi. Eski evlerde tanımlı değilse en çok kullanılan para birimi seçilir.
    var baseCurrencyCode: String {
        if let code = house?.currencyCode, Currency.isSupported(code) { return code }
        let counts = Dictionary(grouping: expenses, by: { $0.currencyCode }).mapValues { $0.count }
        let best = counts.max { a, b in
            a.value == b.value ? a.key > b.key : a.value < b.value
        }
        return best?.key ?? "USD"
    }
    
    var baseCurrency: Currency { Currency.find(baseCurrencyCode) }
    
    /// Bir tutarı evin para birimine çeviren çarpan. Kayıt anındaki kur saklandıysa o kullanılır.
    private func baseFactor(currencyCode: String, amount: Double, storedBase: String?, storedBaseAmount: Double?) -> Double? {
        let base = baseCurrencyCode
        if currencyCode == base { return 1 }
        if storedBase == base, let storedBaseAmount = storedBaseAmount, amount > 0 {
            return storedBaseAmount / amount
        }
        return rates.convertIfPossible(1, from: currencyCode, to: base)
    }
    
    func baseFactor(for expense: Expense) -> Double? {
        baseFactor(currencyCode: expense.currencyCode, amount: expense.amount,
                   storedBase: expense.baseCurrency, storedBaseAmount: expense.baseAmount)
    }
    
    func baseFactor(for settlement: Settlement) -> Double? {
        baseFactor(currencyCode: settlement.currencyCode, amount: settlement.amount,
                   storedBase: settlement.baseCurrency, storedBaseAmount: settlement.baseAmount)
    }
    
    func baseAmount(of expense: Expense) -> Double {
        expense.amount * (baseFactor(for: expense) ?? 1)
    }
    
    /// Kur olmadığı için evin para birimine çevrilemeyen kayıt var mı?
    var hasUnconvertibleItems: Bool {
        expenses.contains { baseFactor(for: $0) == nil } || settlements.contains { baseFactor(for: $0) == nil }
    }
    
    /// Ana para birimindeki bir tutarı başka bir para biriminde göstermek için
    func display(_ baseValue: Double, in currency: Currency) -> Double {
        rates.convert(baseValue, from: baseCurrencyCode, to: currency.code)
    }
    
    func canDisplay(in currency: Currency) -> Bool {
        rates.canConvert(from: baseCurrencyCode, to: currency.code)
    }
    
    // MARK: - Balances
    /// Ana para biriminde kişi başı bakiye (+ alacaklı, - borçlu)
    var balances: [String: Double] {
        var result: [String: Double] = [:]
        for expense in expenses {
            let factor = baseFactor(for: expense) ?? 1
            result[expense.paidBy, default: 0] += expense.amount * factor
            for (uid, share) in expense.splits {
                result[uid, default: 0] -= share * factor
            }
        }
        for settlement in settlements {
            let amount = settlement.amount * (baseFactor(for: settlement) ?? 1)
            result[settlement.fromUser, default: 0] += amount
            result[settlement.toUser, default: 0] -= amount
        }
        return result
    }
    
    var transactions: [DebtTransaction] {
        DebtCalculator.simplify(balances: balances)
    }
    
    var myBalance: Double {
        let value = balances[currentUserId] ?? 0
        return abs(value) < 0.005 ? 0 : value
    }
    
    func balance(of uid: String) -> Double {
        let value = balances[uid] ?? 0
        return abs(value) < 0.005 ? 0 : value
    }
    
    /// Sizin ödediğiniz toplam (ana para biriminde, tüm zamanlar)
    var totalPaidByMe: Double {
        expenses.filter { $0.paidBy == currentUserId }.reduce(0) { $0 + baseAmount(of: $1) }
    }
    
    /// Bir harcamada sizin payınız (ana para biriminde)
    func myShare(of expense: Expense) -> Double {
        (expense.splits[currentUserId] ?? 0) * (baseFactor(for: expense) ?? 1)
    }
    
    // MARK: - Expense queries
    func expenses(inMonthOf date: Date) -> [Expense] {
        expenses.filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .month) }
    }
    
    func total(of list: [Expense], in currency: Currency) -> Double {
        list.reduce(0) { $0 + display(baseAmount(of: $1), in: currency) }
    }
    
    /// Harcama olan aylar (en yeni en başta), içinde bulunulan ay her zaman dahil
    var monthsWithExpenses: [Date] {
        let calendar = Calendar.current
        var months = Set(expenses.compactMap { calendar.dateInterval(of: .month, for: $0.date)?.start })
        if let current = calendar.dateInterval(of: .month, for: Date())?.start {
            months.insert(current)
        }
        return months.sorted(by: >)
    }
    
    // MARK: - Expense mutations
    func addExpense(title: String, amount: Double, currency: Currency, category: String,
                    paidBy: String, splits: [String: Double], splitMode: String,
                    date: Date, completion: @escaping Completion) {
        let ref = firebase.expenses(houseId).document()
        var expense = Expense(
            houseId: houseId,
            title: title,
            amount: amount,
            currencyCode: currency.code,
            category: category,
            paidBy: paidBy,
            splitBetween: memberIds.filter { splits[$0] != nil } + splits.keys.filter { !memberIds.contains($0) },
            splits: splits,
            date: date,
            createdAt: Date(),
            createdBy: currentUserId,
            splitMode: splitMode
        )
        applyBaseConversion(to: &expense)
        
        do {
            try ref.setData(from: expense) { error in
                DispatchQueue.main.async {
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func updateExpense(original: Expense, edited: Expense, completion: @escaping Completion) {
        guard let id = original.id else {
            completion(false, "This expense can't be edited.")
            return
        }
        var expense = edited
        expense.houseId = houseId
        // Tutar ya da para birimi değiştiyse kur yeniden alınır, değişmediyse kayıttaki kur korunur
        if original.amount != edited.amount || original.currencyCode != edited.currencyCode
            || original.baseCurrency != baseCurrencyCode {
            expense.baseCurrency = nil
            expense.baseAmount = nil
            applyBaseConversion(to: &expense)
        }
        do {
            try firebase.expenses(houseId).document(id).setData(from: expense) { error in
                DispatchQueue.main.async {
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func applyBaseConversion(to expense: inout Expense) {
        let base = baseCurrencyCode
        guard expense.currencyCode != base else { return }
        if let converted = rates.convertIfPossible(expense.amount, from: expense.currencyCode, to: base) {
            expense.baseCurrency = base
            expense.baseAmount = converted
        }
    }
    
    func deleteExpense(_ expense: Expense, completion: @escaping Completion) {
        guard let id = expense.id else { return }
        firebase.expenses(houseId).document(id).delete { error in
            DispatchQueue.main.async {
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    // MARK: - Settlements
    /// amount: evin ana para biriminde
    func recordSettlement(from: String, to: String, amount: Double, completion: @escaping Completion) {
        let base = baseCurrencyCode
        let settlement = Settlement(
            houseId: houseId,
            fromUser: from,
            toUser: to,
            amount: baseCurrency.rounded(amount),
            currencyCode: base,
            settled: true,
            settledAt: Date(),
            createdAt: Date(),
            createdBy: currentUserId,
            baseCurrency: base,
            baseAmount: baseCurrency.rounded(amount)
        )
        do {
            try firebase.settlements(houseId).document().setData(from: settlement) { error in
                DispatchQueue.main.async {
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func deleteSettlement(_ settlement: Settlement, completion: @escaping Completion) {
        guard let id = settlement.id else { return }
        firebase.settlements(houseId).document(id).delete { error in
            DispatchQueue.main.async {
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    func canUndo(_ settlement: Settlement) -> Bool {
        settlement.fromUser == currentUserId || settlement.toUser == currentUserId
    }
    
    // MARK: - Chores
    func addChore(title: String, assignedTo: [String], dueDate: Date, frequency: ChoreFrequency, completion: @escaping Completion) {
        let chore = Chore(
            houseId: houseId,
            title: title,
            assignedTo: assignedTo,
            dueDate: dueDate,
            frequency: frequency.rawValue,
            createdBy: currentUserId
        )
        do {
            try firebase.chores(houseId).document().setData(from: chore) { error in
                DispatchQueue.main.async {
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func updateChore(_ chore: Chore, completion: @escaping Completion) {
        guard let id = chore.id else {
            completion(false, "This chore can't be edited.")
            return
        }
        var updated = chore
        updated.houseId = houseId
        do {
            try firebase.chores(houseId).document(id).setData(from: updated) { error in
                DispatchQueue.main.async {
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func deleteChore(_ chore: Chore, completion: @escaping Completion) {
        guard let id = chore.id else { return }
        firebase.chores(houseId).document(id).delete { error in
            DispatchQueue.main.async {
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    /// Tekrarlayan bir görevin bekleyen tüm kopyalarını siler (geçmiş tamamlananlar kalır)
    func deleteSeries(of chore: Chore, completion: @escaping Completion) {
        let targets = chores.filter {
            !$0.completed && $0.title == chore.title && $0.frequency == chore.frequency
        }
        deleteChores(targets, completion: completion)
    }
    
    /// Tamamlanmış tüm görevleri temizler
    func clearCompletedChores(completion: @escaping Completion) {
        deleteChores(chores.filter { $0.completed }, completion: completion)
    }
    
    private func deleteChores(_ list: [Chore], completion: @escaping Completion) {
        let ids = list.compactMap { $0.id }
        guard !ids.isEmpty else {
            completion(true, nil)
            return
        }
        let batch = db.batch()
        for id in ids.prefix(450) {
            batch.deleteDocument(firebase.chores(houseId).document(id))
        }
        batch.commit { error in
            DispatchQueue.main.async {
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    func toggleComplete(_ chore: Chore) {
        guard let choreId = chore.id else { return }
        let newStatus = !chore.completed
        
        var updateData: [String: Any] = ["completed": newStatus]
        if newStatus {
            updateData["completedAt"] = Timestamp(date: Date())
            updateData["completedBy"] = currentUserId
        } else {
            updateData["completedAt"] = NSNull()
            updateData["completedBy"] = NSNull()
        }
        // Eski dokümanlarda eksik olabilecek alanlar (kurallar bunları ister)
        updateData["houseId"] = houseId
        updateData["frequency"] = chore.frequency
        updateData["assignedTo"] = chore.assignedTo
        
        firebase.chores(houseId).document(choreId).updateData(updateData) { error in
            if let error = error {
                ToastManager.shared.show(FriendlyError.message(for: error), type: .error)
            }
        }
        
        // Tekrarlayan görev: tamamlanınca sonrakini oluştur, geri alınınca (dokunulmamış) sonrakini kaldır
        guard chore.isRecurring, let nextDate = nextDueDate(for: chore) else { return }
        if newStatus {
            createNextRecurrence(from: chore, dueDate: nextDate)
        } else {
            removePendingRecurrence(of: chore, dueDate: nextDate)
        }
    }
    
    /// Bir sonraki tarih; görev gecikmişse bugünden önceki tekrarlar atlanır
    private func nextDueDate(for chore: Chore) -> Date? {
        guard let frequency = ChoreFrequency(rawValue: chore.frequency),
              var next = frequency.next(after: chore.dueDate) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        var guardCounter = 0
        while next < today, guardCounter < 400, let candidate = frequency.next(after: next) {
            next = candidate
            guardCounter += 1
        }
        return next
    }
    
    private func isRecurrence(_ candidate: Chore, of chore: Chore, dueDate: Date) -> Bool {
        candidate.id != chore.id
            && !candidate.completed
            && candidate.title == chore.title
            && candidate.frequency == chore.frequency
            && Calendar.current.isDate(candidate.dueDate, inSameDayAs: dueDate)
    }
    
    private func createNextRecurrence(from chore: Chore, dueDate: Date) {
        if chores.contains(where: { isRecurrence($0, of: chore, dueDate: dueDate) }) { return }
        let next = Chore(
            houseId: houseId,
            title: chore.title,
            assignedTo: chore.assignedTo.filter { memberIds.contains($0) },
            dueDate: dueDate,
            frequency: chore.frequency,
            completed: false,
            createdBy: chore.createdBy.isEmpty ? currentUserId : chore.createdBy
        )
        do {
            try firebase.chores(houseId).document().setData(from: next) { error in
                if let error = error {
                    print("🔴 createNextRecurrence error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("🔴 createNextRecurrence encode error: \(error)")
        }
    }
    
    private func removePendingRecurrence(of chore: Chore, dueDate: Date) {
        for candidate in chores where isRecurrence(candidate, of: chore, dueDate: dueDate) {
            guard let id = candidate.id else { continue }
            firebase.chores(houseId).document(id).delete()
        }
    }
    
    // MARK: - House management
    private var houseRef: DocumentReference { firebase.houses.document(houseId) }
    
    private func finish(_ completion: @escaping Completion) -> (Error?) -> Void {
        return { error in
            DispatchQueue.main.async {
                completion(error == nil, error.map { FriendlyError.message(for: $0) })
            }
        }
    }
    
    func renameHouse(_ name: String, completion: @escaping Completion) {
        houseRef.updateData(["houseName": name], completion: finish(completion))
    }
    
    func setHouseImage(_ data: Data?, completion: @escaping Completion) {
        let value: Any
        if let data = data {
            value = data.base64EncodedString()
        } else {
            value = FieldValue.delete()
        }
        houseRef.updateData(["imageBase64": value], completion: finish(completion))
    }
    
    func setBaseCurrency(_ currency: Currency, completion: @escaping Completion) {
        houseRef.updateData(["currencyCode": currency.code], completion: finish(completion))
    }
    
    func setAdmin(_ uid: String, isAdmin: Bool, completion: @escaping Completion) {
        let value = isAdmin ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
        houseRef.updateData(["admins": value], completion: finish(completion))
    }
    
    func transferOwnership(to uid: String, completion: @escaping Completion) {
        guard let house = house, isOwner, house.members.contains(uid) else {
            completion(false, "Only the owner can transfer ownership.")
            return
        }
        // Eski sahip admin olarak kalır
        var newAdmins = house.adminList.filter { $0 != uid && house.members.contains($0) }
        if !newAdmins.contains(currentUserId) { newAdmins.append(currentUserId) }
        houseRef.updateData([
            "createdBy": uid,
            "admins": newAdmins
        ], completion: finish(completion))
    }
    
    /// Üyeyi çıkarır ve davet kodunu yeniler (çıkarılan kişi eski kodla geri giremesin)
    func removeMember(_ uid: String, completion: @escaping Completion) {
        guard let house = house, uid != house.createdBy else {
            completion(false, "The owner can't be removed.")
            return
        }
        let name = fullName(for: uid)
        replaceInviteCode(extraHouseUpdates: [
            "members": FieldValue.arrayRemove([uid]),
            "admins": FieldValue.arrayRemove([uid]),
            "pastMembers.\(uid)": name
        ], completion: completion)
    }
    
    func regenerateInviteCode(completion: @escaping Completion) {
        replaceInviteCode(extraHouseUpdates: [:], completion: completion)
    }
    
    private func replaceInviteCode(extraHouseUpdates: [String: Any], attempt: Int = 0, completion: @escaping Completion) {
        guard let oldCode = house?.inviteCode else {
            completion(false, "House not loaded yet.")
            return
        }
        let newCode = HouseViewModel.generateInviteCode()
        let oldInviteRef = firebase.invites.document(oldCode)
        
        oldInviteRef.getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }
            let batch = self.db.batch()
            // Eski kod bu eve aitse sil
            if let snapshot = snapshot, snapshot.exists,
               (snapshot.data()?["houseId"] as? String) == self.houseId {
                batch.deleteDocument(oldInviteRef)
            }
            batch.setData([
                "houseId": self.houseId,
                "createdBy": self.currentUserId,
                "createdAt": Timestamp(date: Date())
            ], forDocument: self.firebase.invites.document(newCode))
            
            var houseUpdates = extraHouseUpdates
            houseUpdates["inviteCode"] = newCode
            batch.updateData(houseUpdates, forDocument: self.houseRef)
            
            batch.commit { error in
                DispatchQueue.main.async {
                    if let error = error, attempt < 2, !FriendlyError.message(for: error).contains("offline") {
                        // Kod başka bir eve aitse (çok düşük ihtimal) yeni kodla tekrar dene
                        self.replaceInviteCode(extraHouseUpdates: extraHouseUpdates, attempt: attempt + 1, completion: completion)
                        return
                    }
                    completion(error == nil, error.map { FriendlyError.message(for: $0) })
                }
            }
        }
    }
    
    /// Eski sürümde oluşturulan evlerin davet kodunu yeni "invites" koleksiyonuna ekler
    private func ensureInviteExists(for house: House) {
        guard !didEnsureInvite, house.isAdmin(currentUserId) else { return }
        didEnsureInvite = true
        let ref = firebase.invites.document(house.inviteCode)
        ref.getDocument { [weak self] snapshot, error in
            guard let self = self, error == nil, let snapshot = snapshot else { return }
            if !snapshot.exists {
                ref.setData([
                    "houseId": self.houseId,
                    "createdBy": self.currentUserId,
                    "createdAt": Timestamp(date: Date())
                ]) { error in
                    if let error = error {
                        print("⚠️ Could not create invite: \(error.localizedDescription)")
                    }
                }
            } else if (snapshot.data()?["houseId"] as? String) != self.houseId {
                // Kod başka bir eve ait → bu ev için yeni kod üret
                self.regenerateInviteCode { _, _ in }
            }
        }
    }
    
    /// Evden ayrılır. Son üye sahipse ev ve tüm verisi silinir; değilse sahiplik devredilir.
    func leaveHouse(completion: @escaping Completion) {
        guard let house = house else {
            // Ev okunamıyorsa en azından kullanıcıyı evden çıkar
            firebase.clearHouseId(userId: currentUserId) { success in
                DispatchQueue.main.async { completion(success, success ? nil : "Couldn't leave the house.") }
            }
            return
        }
        let userRef = firebase.users.document(currentUserId)
        let remaining = house.members.filter { $0 != currentUserId }
        
        if remaining.isEmpty {
            deleteHouseCompletely(house: house, completion: completion)
            return
        }
        
        var updates: [String: Any] = [
            "members": FieldValue.arrayRemove([currentUserId]),
            "admins": FieldValue.arrayRemove([currentUserId]),
            "pastMembers.\(currentUserId)": fullName(for: currentUserId)
        ]
        if house.createdBy == currentUserId {
            let newOwner = remaining.first(where: { house.adminList.contains($0) }) ?? remaining[0]
            updates["createdBy"] = newOwner
        }
        
        let batch = db.batch()
        batch.updateData(updates, forDocument: houseRef)
        batch.updateData(["houseId": FieldValue.delete()], forDocument: userRef)
        batch.commit(completion: finish(completion))
    }
    
    private func deleteHouseCompletely(house: House, completion: @escaping Completion) {
        let collections = [firebase.expenses(houseId), firebase.settlements(houseId), firebase.chores(houseId)]
        deleteAllDocuments(in: collections) { [weak self] in
            guard let self = self else { return }
            let inviteRef = self.firebase.invites.document(house.inviteCode)
            inviteRef.getDocument { snapshot, _ in
                let batch = self.db.batch()
                if let snapshot = snapshot, snapshot.exists,
                   (snapshot.data()?["houseId"] as? String) == self.houseId {
                    batch.deleteDocument(inviteRef)
                }
                batch.deleteDocument(self.houseRef)
                batch.updateData(["houseId": FieldValue.delete()],
                                 forDocument: self.firebase.users.document(self.currentUserId))
                batch.commit(completion: self.finish(completion))
            }
        }
    }
    
    private func deleteAllDocuments(in collections: [CollectionReference], completion: @escaping () -> Void) {
        guard let first = collections.first else {
            completion()
            return
        }
        let rest = Array(collections.dropFirst())
        first.limit(to: 400).getDocuments { [weak self] snapshot, _ in
            guard let self = self else { return }
            let docs = snapshot?.documents ?? []
            if docs.isEmpty {
                self.deleteAllDocuments(in: rest, completion: completion)
                return
            }
            let batch = self.db.batch()
            docs.forEach { batch.deleteDocument($0.reference) }
            batch.commit { error in
                if error != nil {
                    // Silinemeyenleri atla; ev silindiğinde zaten kimse erişemez
                    self.deleteAllDocuments(in: rest, completion: completion)
                } else {
                    // Aynı koleksiyonda kalan varsa devam et
                    self.deleteAllDocuments(in: collections, completion: completion)
                }
            }
        }
    }
    
    // MARK: - Legacy migration
    /// Eski sürümde üst seviye koleksiyonlarda tutulan verileri evin altına taşır (bir kerelik)
    private func migrateLegacyDataIfNeeded() {
        guard !didAttemptMigration else { return }
        didAttemptMigration = true
        for name in ["expenses", "settlements", "chores"] {
            migrateLegacyCollection(name)
        }
    }
    
    private func migrateLegacyCollection(_ name: String) {
        let legacy = db.collection(name).whereField("houseId", isEqualTo: houseId).limit(to: 200)
        let target = firebase.houses.document(houseId).collection(name)
        legacy.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("ℹ️ Legacy \(name) not migrated: \(error.localizedDescription)")
                return
            }
            guard let docs = snapshot?.documents, !docs.isEmpty else { return }
            let batch = self.db.batch()
            for doc in docs {
                batch.setData(doc.data(), forDocument: target.document(doc.documentID))
                batch.deleteDocument(doc.reference)
            }
            batch.commit { error in
                if let error = error {
                    print("🔴 Legacy \(name) migration failed: \(error.localizedDescription)")
                } else {
                    print("✅ Migrated \(docs.count) legacy \(name)")
                    if docs.count == 200 { self.migrateLegacyCollection(name) }
                }
            }
        }
    }
}

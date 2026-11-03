import SwiftUI

enum ChoreFilter: String, CaseIterable, Hashable {
    case pending = "Pending"
    case completed = "Completed"
}

struct ChoresView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @State var showAddChore = false
    @State var editingChore: Chore?
    @State var selectedFilter: ChoreFilter = .pending
    @AppStorage("choresOnlyMine") var onlyMine = false
    @State var chorePendingDelete: Chore?
    @State var showClearCompleted = false
    
    var me: String { store.currentUserId }
    
    var pendingChores: [Chore] { store.chores.filter { !$0.completed } }
    var completedChores: [Chore] { store.chores.filter { $0.completed } }
    var overdueCount: Int { pendingChores.filter { $0.isOverdue && (!onlyMine || $0.assignedTo.contains(me)) }.count }
    
    /// Bu hafta tamamlananlar
    var completedThisWeek: [Chore] {
        let now = Date()
        return completedChores.filter { chore in
            guard let completedAt = chore.completedAt else { return false }
            return Calendar.current.isDate(completedAt, equalTo: now, toGranularity: .weekOfYear)
        }
    }
    
    /// Bu hafta bitmesi gereken (ya da gecikmiş) bekleyen görevler
    var pendingThisWeek: [Chore] {
        let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
        return pendingChores.filter { $0.dueDate < endOfWeek }
    }
    
    var filteredChores: [Chore] {
        let base = selectedFilter == .pending ? pendingChores : completedChores
        return onlyMine ? base.filter { $0.assignedTo.contains(me) } : base
    }
    
    var existingPendingTitles: Set<String> {
        Set(pendingChores.map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        progressCard
                        addChoreButton
                        filterBar
                        choresList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddChore) {
                AddChoreView(existingPendingTitles: existingPendingTitles)
                    .environmentObject(authVM)
                    .environmentObject(store)
            }
            .sheet(item: $editingChore) { chore in
                AddChoreView(editingChore: chore)
                    .environmentObject(authVM)
                    .environmentObject(store)
            }
            .confirmationDialog(
                "Delete chore?",
                isPresented: Binding(
                    get: { chorePendingDelete != nil },
                    set: { if !$0 { chorePendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: chorePendingDelete
            ) { chore in
                Button("Delete This Chore", role: .destructive) { delete(chore) }
                if chore.isRecurring && !chore.completed {
                    Button("Delete All Upcoming Repeats", role: .destructive) { deleteSeries(chore) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { chore in
                Text(chore.title)
            }
            .alert("Clear completed chores?", isPresented: $showClearCompleted) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { clearCompleted() }
            } message: {
                Text("This removes \(completedChores.count) completed chores for everyone. \"Chores Done\" stats will reset.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Progress Card
    var progressCard: some View {
        let total = pendingThisWeek.count + completedThisWeek.count
        let progress = total > 0 ? Double(completedThisWeek.count) / Double(total) : 0
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(AppTheme.heroGradient)
                .overlay(
                    Circle()
                        .fill(AppTheme.amber.opacity(0.15))
                        .frame(width: 150, height: 150)
                        .blur(radius: 40)
                        .offset(x: 110, y: -40)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                
                Text("\(pendingThisWeek.count) to do")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                ProgressView(value: progress)
                    .tint(AppTheme.mint)
                    .padding(.trailing, 20)
                
                HStack(spacing: 12) {
                    Text("\(completedThisWeek.count) of \(total) done")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                    if overdueCount > 0 {
                        Label("\(overdueCount) overdue", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.coral)
                    }
                }
            }
            .padding(20)
        }
    }
    
    var addChoreButton: some View {
        Button(action: { showAddChore = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Chore").fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.violetGradient)
            .cornerRadius(14)
        }
    }
    
    // MARK: - Filter Bar
    var filterBar: some View {
        VStack(spacing: 10) {
            PillPicker(options: ChoreFilter.allCases, selection: $selectedFilter, label: { $0.rawValue })
            
            HStack {
                Button(action: { onlyMine.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: onlyMine ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                        Text("Only Mine")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(onlyMine ? AppTheme.mint : AppTheme.textMuted)
                }
                Spacer()
                if selectedFilter == .completed && !completedChores.isEmpty {
                    Button(action: { showClearCompleted = true }) {
                        Text("Clear completed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.coral)
                    }
                }
            }
        }
    }
    
    // MARK: - Chores List
    var choresList: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.isLoadingChores {
                ProgressView()
                    .tint(AppTheme.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if filteredChores.isEmpty {
                EmptyStateView(
                    icon: selectedFilter == .pending ? "checklist" : "checkmark.circle",
                    title: selectedFilter == .pending ? "No pending chores" : "No completed chores yet",
                    message: selectedFilter == .pending ? "Tap Add Chore to assign a task" : "Completed tasks will show up here"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredChores) { chore in
                        ChoreCard(
                            chore: chore,
                            assignee: assigneeText(for: chore),
                            onToggle: { toggle(chore) },
                            onEdit: { editingChore = chore },
                            onDelete: { chorePendingDelete = chore }
                        )
                    }
                }
            }
        }
    }
    
    func assigneeText(for chore: Chore) -> String {
        let current = chore.assignedTo.filter { store.isCurrentMember($0) }
        if current.count > 1 && current.count == store.memberIds.count {
            return "Everyone"
        }
        let names = chore.assignedTo.map { store.name(for: $0) }
        return names.isEmpty ? "Unassigned" : names.joined(separator: ", ")
    }
    
    func toggle(_ chore: Chore) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleComplete(chore)
        }
    }
    
    func delete(_ chore: Chore) {
        store.deleteChore(chore) { success, error in
            if success {
                ToastManager.shared.show("Chore deleted", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to delete chore", type: .error)
            }
        }
    }
    
    func deleteSeries(_ chore: Chore) {
        store.deleteSeries(of: chore) { success, error in
            if success {
                ToastManager.shared.show("Repeating chore deleted", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to delete chores", type: .error)
            }
        }
    }
    
    func clearCompleted() {
        store.clearCompletedChores { success, error in
            if success {
                ToastManager.shared.show("Completed chores cleared", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to clear chores", type: .error)
            }
        }
    }
}

// MARK: - Chore Card
struct ChoreCard: View {
    let chore: Chore
    let assignee: String
    let onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var dueText: String {
        if chore.completed, let completedAt = chore.completedAt {
            return "Done \(completedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if chore.isDueToday { return "Due today" }
        if Calendar.current.isDateInTomorrow(chore.dueDate) { return "Due tomorrow" }
        if chore.isOverdue {
            let days = Calendar.current.dateComponents([.day],
                                                       from: Calendar.current.startOfDay(for: chore.dueDate),
                                                       to: Calendar.current.startOfDay(for: Date())).day ?? 0
            return days == 1 ? "Overdue by 1 day" : "Overdue by \(days) days"
        }
        return chore.dueDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    var dueColor: Color {
        if chore.isOverdue { return AppTheme.coral }
        if chore.isDueToday { return AppTheme.amber }
        return AppTheme.textMuted
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(chore.completed ? AppTheme.mint : AppTheme.textMuted, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if chore.completed {
                        Circle()
                            .fill(AppTheme.mint)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, -9)
            .accessibilityLabel(chore.completed ? "Mark as not done" : "Mark as done")
            
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: ChoreIcon.icon(for: chore.title))
                    .foregroundColor(AppTheme.violet)
                    .font(.system(size: 16))
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(chore.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(chore.completed ? AppTheme.textMuted : AppTheme.textPrimary)
                        .strikethrough(chore.completed)
                        .lineLimit(1)
                    if chore.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.violet)
                            .accessibilityLabel(ChoreFrequency(rawValue: chore.frequency)?.label ?? "Repeats")
                    }
                }
                HStack(spacing: 4) {
                    Text(assignee)
                        .lineLimit(1)
                    Text("·")
                    Text(dueText)
                        .foregroundColor(dueColor)
                        .lineLimit(1)
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
            }
            
            Spacer()
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(chore.isOverdue ? AppTheme.coral.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onEdit?() }
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            }
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

import SwiftUI

struct AddChoreView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var store: HouseStore
    @Environment(\.dismiss) var dismiss
    
    var editingChore: Chore? = nil
    var existingPendingTitles: Set<String> = []
    
    @State var title = ""
    @State var dueDate = Date()
    @State var frequency: ChoreFrequency = .oneTime
    @State var selectedAssigneeIds: Set<String> = []
    @State var selectedPresetCategory: ChoreCategoryGroup = ChoreCategoryGroup.all[0]
    @State var didLoad = false
    @State var showDeleteConfirmation = false
    
    var isEditing: Bool { editingChore != nil }
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var members: [AppUser] { store.memberList }
    var isEveryoneSelected: Bool { !members.isEmpty && members.allSatisfy { selectedAssigneeIds.contains($0.id ?? "") } }
    
    var isFormValid: Bool {
        !trimmedTitle.isEmpty && trimmedTitle.count <= 80 && !selectedAssigneeIds.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        taskField
                        if !isEditing { quickAddSection }
                        assignSection
                        dueDateField
                        repeatField
                        PrimaryButton(title: isEditing ? "Update Chore" : "Add Chore",
                                      gradient: AppTheme.violetGradient, isEnabled: isFormValid) {
                            saveChore()
                        }
                        .padding(.top, 6)
                        
                        if isEditing {
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                Label("Delete Chore", systemImage: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.coral)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.coral.opacity(0.1))
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Chore" : "New Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .alert("Delete this chore?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteChore() }
            }
            .onAppear(perform: loadInitialValues)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Task Field
    var taskField: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("TASK")
            ThemedTextField(placeholder: "e.g. Take out trash", text: $title)
        }
    }
    
    // MARK: - Quick Add
    var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("QUICK ADD")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChoreCategoryGroup.all) { group in
                        Button(action: { selectedPresetCategory = group }) {
                            HStack(spacing: 6) {
                                Image(systemName: group.icon).font(.system(size: 12))
                                Text(group.name).font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(selectedPresetCategory.id == group.id ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedPresetCategory.id == group.id ? group.color : Color.white.opacity(0.06))
                            .cornerRadius(20)
                        }
                    }
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(selectedPresetCategory.chores) { preset in
                    Button(action: { title = preset.title }) {
                        HStack(spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 13))
                                .foregroundColor(selectedPresetCategory.color)
                            Text(preset.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(title == preset.title ? selectedPresetCategory.color.opacity(0.15) : Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(title == preset.title ? selectedPresetCategory.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Assign Section
    var assignSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FieldLabel("ASSIGN TO")
                Spacer()
                Button(action: toggleEveryone) {
                    Text(isEveryoneSelected ? "Deselect All" : "Everyone")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.violet)
                }
            }
            VStack(spacing: 8) {
                ForEach(members) { member in
                    let uid = member.id ?? ""
                    SelectableMemberRow(
                        user: member,
                        isYou: uid == store.currentUserId,
                        isSelected: selectedAssigneeIds.contains(uid),
                        tint: AppTheme.violet
                    ) {
                        if selectedAssigneeIds.contains(uid) {
                            selectedAssigneeIds.remove(uid)
                        } else {
                            selectedAssigneeIds.insert(uid)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Due Date
    var dueDateField: some View {
        HStack {
            FieldLabel("DUE DATE")
            Spacer()
            DatePicker("", selection: $dueDate, displayedComponents: .date)
                .labelsHidden()
                .tint(AppTheme.violet)
        }
        .padding(12)
        .glassCard()
    }
    
    // MARK: - Repeat
    var repeatField: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("REPEAT")
            PillPicker(options: ChoreFrequency.allCases, selection: $frequency, label: { $0.label })
            if frequency != .oneTime {
                Text("When it's marked done, the next one is created automatically.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.leading, 4)
            }
        }
    }
    
    // MARK: - Actions
    func toggleEveryone() {
        if isEveryoneSelected {
            selectedAssigneeIds.removeAll()
        } else {
            selectedAssigneeIds = Set(members.compactMap { $0.id })
        }
    }
    
    func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if let chore = editingChore {
            title = chore.title
            dueDate = chore.dueDate
            frequency = ChoreFrequency(rawValue: chore.frequency) ?? .oneTime
            selectedAssigneeIds = Set(chore.assignedTo.filter { store.isCurrentMember($0) })
        } else {
            selectedAssigneeIds = [store.currentUserId]
        }
    }
    
    func saveChore() {
        guard isFormValid else { return }
        // Sadece hâlâ evde olan kişiler atanabilir
        let assignees = store.memberIds.filter { selectedAssigneeIds.contains($0) }
        
        if editingChore == nil && existingPendingTitles.contains(trimmedTitle.lowercased()) {
            ToastManager.shared.show("This chore is already pending", type: .error)
            return
        }
        
        if var chore = editingChore {
            chore.title = trimmedTitle
            chore.assignedTo = assignees
            chore.dueDate = dueDate
            chore.frequency = frequency.rawValue
            store.updateChore(chore) { success, error in
                if success {
                    ToastManager.shared.show("Chore updated", type: .success)
                } else {
                    ToastManager.shared.show(error ?? "Failed to update chore", type: .error)
                }
            }
        } else {
            store.addChore(title: trimmedTitle, assignedTo: assignees, dueDate: dueDate, frequency: frequency) { success, error in
                if success {
                    ToastManager.shared.show("Chore added", type: .success)
                } else {
                    ToastManager.shared.show(error ?? "Failed to add chore", type: .error)
                }
            }
        }
        dismiss()
    }
    
    func deleteChore() {
        guard let chore = editingChore else { return }
        store.deleteChore(chore) { success, error in
            if success {
                ToastManager.shared.show("Chore deleted", type: .success)
            } else {
                ToastManager.shared.show(error ?? "Failed to delete chore", type: .error)
            }
        }
        dismiss()
    }
}

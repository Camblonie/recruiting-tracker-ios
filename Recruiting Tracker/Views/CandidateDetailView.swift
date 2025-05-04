import SwiftUI
import SwiftData
import PhotosUI
import Combine

struct CandidateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let candidate: Candidate
    
    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAvoidWarning = false
    @State private var showingAvoidHistory = false
    @State private var avoidFlagReason = ""
    @State private var tempAvoidFlag = false
    
    var body: some View {
        List {
            // Basic Information
            Section("Basic Information") {
                LabeledContent("Name", value: candidate.name)
                LabeledContent("Phone", value: candidate.phoneNumber)
                LabeledContent("Email", value: candidate.email)
                LabeledContent("Lead Source", value: candidate.leadSource.rawValue)
                if let referralName = candidate.referralName {
                    LabeledContent("Referred By", value: referralName)
                }
            }
            
            // Experience
            Section("Experience") {
                LabeledContent("Years of Experience", value: "\(candidate.yearsOfExperience)")
                LabeledContent("Technician Level", value: candidate.technicianLevel.rawValue)
                
                DisclosureGroup("Previous Employers") {
                    ForEach(candidate.previousEmployers, id: \.self) { employer in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                            Text(employer.rawValue)
                        }
                    }
                }
                
                DisclosureGroup("Technical Focus") {
                    ForEach(candidate.technicalFocus, id: \.self) { focus in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                            Text(focus.rawValue)
                        }
                    }
                }
            }
            
            // Status
            Section("Status") {
                LabeledContent("Hiring Status", value: candidate.hiringStatus.rawValue)
                Toggle("Needs Follow-up", isOn: .constant(candidate.needsFollowUp))
                Toggle("Hot Candidate", isOn: .constant(candidate.isHotCandidate))
                
                Toggle("Avoid Candidate", isOn: Binding(
                    get: { candidate.avoidCandidate },
                    set: { newValue in
                        tempAvoidFlag = newValue
                        if newValue {
                            showingAvoidWarning = true
                        } else {
                            // If turning off, show warning if there's history
                            if !candidate.avoidFlagHistory.isEmpty {
                                showingAvoidWarning = true
                            } else {
                                candidate.updateAvoidFlag(to: newValue)
                            }
                        }
                    }
                ))
                
                if !candidate.avoidFlagHistory.isEmpty {
                    Button("View Avoid Flag History") {
                        showingAvoidHistory = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Compensation
            Section("Compensation") {
                if let payScale = candidate.conceptPayScale {
                    LabeledContent("Pay Scale", value: payScale)
                }
                if let payDate = candidate.conceptPayDate {
                    LabeledContent("Pay Scale Date", value: payDate.formatted(date: .numeric, time: .omitted))
                }
                LabeledContent("Needs Insurance", value: candidate.needsHealthInsurance ? "Yes" : "No")
            }
            
            // Additional Information
            Section("Additional Information") {
                if let offerDetail = candidate.offerDetail {
                    Text("Offer Details: \(offerDetail)")
                }
                
                if let offerDate = candidate.offerDate {
                    LabeledContent("Offer Date", value: offerDate.formatted(date: .numeric, time: .omitted))
                }
                
                if let picture = candidate.picture, let uiImage = UIImage(data: picture) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                
                if !candidate.socialMediaLinks.isEmpty {
                    DisclosureGroup("Social Media") {
                        ForEach(candidate.socialMediaLinks, id: \.self) { link in
                            Text(link)
                        }
                    }
                }
                
                if !candidate.notes.isEmpty {
                    DisclosureGroup("Notes") {
                        Text(candidate.notes)
                    }
                }
                
                LabeledContent("Date Entered", value: candidate.dateEntered.formatted(date: .numeric, time: .omitted))
            }
            
            // Actions
            Section {
                Button("Edit Candidate") {
                    showingEditForm = true
                }
                .foregroundColor(.blue)
                
                NavigationLink("Attached Files") {
                    FileAttachmentView(candidate: candidate)
                }
                
                Button("Share Candidate Info (set in settings)") {
                    shareCandidate()
                }
                .foregroundColor(.blue)
                
                Button("Delete Candidate", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(candidate.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditForm = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.terracotta)
                }
            }
        }
        .alert("Delete Candidate", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteCandidate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this candidate? This action cannot be undone.")
        }
        .alert("Avoid Candidate Flag", isPresented: $showingAvoidWarning) {
            TextField("Reason for change", text: $avoidFlagReason)
            Button("Cancel", role: .cancel) {
                tempAvoidFlag = candidate.avoidCandidate // Reset to current value
            }
            Button(tempAvoidFlag ? "Mark as Avoid" : "Remove Avoid Flag") {
                candidate.updateAvoidFlag(to: tempAvoidFlag, reason: avoidFlagReason)
                avoidFlagReason = "" // Reset reason
            }
        } message: {
            Text(tempAvoidFlag
                 ? "Please provide a reason for marking this candidate as 'avoid'."
                 : "Please provide a reason for removing the avoid flag.")
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationView {
                CandidateEditView(candidate: candidate, isPresented: $showingEditForm)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingAvoidHistory) {
            NavigationView {
                List {
                    ForEach(candidate.avoidFlagHistory, id: \.date) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.date.formatted())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(entry.isEnabled ? "Marked as Avoid" : "Avoid Flag Removed")
                                .font(.headline)
                            
                            if let reason = entry.reason {
                                Text("Reason: \(reason)")
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Avoid Flag History")
                .navigationBarItems(trailing: Button("Done") {
                    showingAvoidHistory = false
                })
            }
        }
    }
    
    private func shareCandidate() {
        let info = candidate.exportData()
        
        let av = UIActivityViewController(
            activityItems: [info],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
    
    private func deleteCandidate() {
        modelContext.delete(candidate)
        dismiss()
    }
}

// MARK: - Edit View for Existing Candidate
struct CandidateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    let candidate: Candidate
    
    // Form Fields
    @State private var name: String
    @State private var phoneNumber: String
    @State private var email: String
    @State private var leadSource: LeadSource
    @State private var referralName: String
    @State private var yearsOfExperience: Int
    @State private var selectedEmployers: Set<PreviousEmployer>
    @State private var selectedFocus: Set<TechnicalFocus>
    @State private var technicianLevel: TechnicianLevel
    @State private var hiringStatus: HiringStatus
    @State private var selectedPosition: Position?
    @State private var needsFollowUp: Bool
    @State private var isHotCandidate: Bool
    @State private var avoidCandidate: Bool
    @State private var conceptPayScale: String
    @State private var conceptPayDate: Date
    @State private var needsHealthInsurance: Bool
    @State private var offerDetail: String
    @State private var offerDate: Date
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var candidatePhoto: Data?
    @State private var socialMediaLinks: String
    @State private var notes: String
    @State private var dateEntered: Date
    
    // UI State
    @State private var showingValidationError = false
    @State private var validationError: ValidationError?
    @State private var showingAvoidWarning = false
    @State private var avoidFlagReason = ""
    @State private var isProcessing = false
    @State private var showingDeleteConfirmation = false
    
    @Query private var positions: [Position]
    
    init(candidate: Candidate, isPresented: Binding<Bool>) {
        self.candidate = candidate
        self._isPresented = isPresented
        
        // Initialize state from existing candidate
        _name = State(initialValue: candidate.name)
        _phoneNumber = State(initialValue: candidate.phoneNumber)
        _email = State(initialValue: candidate.email)
        _leadSource = State(initialValue: candidate.leadSource)
        _referralName = State(initialValue: candidate.referralName ?? "")
        _yearsOfExperience = State(initialValue: candidate.yearsOfExperience)
        _selectedEmployers = State(initialValue: Set(candidate.previousEmployers))
        _selectedFocus = State(initialValue: Set(candidate.technicalFocus))
        _technicianLevel = State(initialValue: candidate.technicianLevel)
        _hiringStatus = State(initialValue: candidate.hiringStatus)
        _selectedPosition = State(initialValue: candidate.position)
        _needsFollowUp = State(initialValue: candidate.needsFollowUp)
        _isHotCandidate = State(initialValue: candidate.isHotCandidate)
        _avoidCandidate = State(initialValue: candidate.avoidCandidate)
        _conceptPayScale = State(initialValue: candidate.conceptPayScale ?? "")
        _conceptPayDate = State(initialValue: candidate.conceptPayDate ?? Date())
        _needsHealthInsurance = State(initialValue: candidate.needsHealthInsurance)
        _offerDetail = State(initialValue: candidate.offerDetail ?? "")
        _offerDate = State(initialValue: candidate.offerDate ?? Date())
        _candidatePhoto = State(initialValue: candidate.picture)
        _socialMediaLinks = State(initialValue: candidate.socialMediaLinks.joined(separator: ", "))
        _notes = State(initialValue: candidate.notes)
        _dateEntered = State(initialValue: candidate.dateEntered)
    }
    
    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                
                PhoneTextField(text: $phoneNumber)
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                Picker("Lead Source", selection: $leadSource) {
                    ForEach(LeadSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                
                if leadSource == .referral {
                    TextField("Referral Name", text: $referralName)
                }
            }
            
            Section("Experience") {
                Stepper("Years of Experience: \(yearsOfExperience)", value: $yearsOfExperience, in: 0...50)
                
                MultiSelectionView(
                    title: "Previous Employers",
                    options: PreviousEmployer.allCases,
                    selected: $selectedEmployers
                )
                
                MultiSelectionView(
                    title: "Technical Focus",
                    options: TechnicalFocus.allCases,
                    selected: $selectedFocus
                )
                
                Picker("Technician Level", selection: $technicianLevel) {
                    ForEach(TechnicianLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
            
            Section("Status") {
                Picker("Hiring Status", selection: $hiringStatus) {
                    ForEach(HiringStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                
                Toggle("Needs Follow-up", isOn: $needsFollowUp)
                Toggle("Hot Candidate", isOn: $isHotCandidate)
                Toggle("Avoid Candidate", isOn: $avoidCandidate)
                    .onChange(of: avoidCandidate) { oldValue, newValue in
                        if newValue != candidate.avoidCandidate {
                            showingAvoidWarning = true
                        }
                    }
                
                if !positions.isEmpty {
                    Picker("Position", selection: $selectedPosition) {
                        Text("No position").tag(nil as Position?)
                        ForEach(positions) { position in
                            Text(position.title).tag(position as Position?)
                        }
                    }
                }
                
                TextField("Pay Scale", text: $conceptPayScale)
                DatePicker("Pay Scale Date", selection: $conceptPayDate, displayedComponents: .date)
                Toggle("Needs Health Insurance", isOn: $needsHealthInsurance)
            }
            
            Section("Additional Information") {
                TextField("Offer Details", text: $offerDetail)
                DatePicker("Offer Date", selection: $offerDate, displayedComponents: .date)
                
                // Existing image preview
                if let picture = candidatePhoto, let uiImage = UIImage(data: picture) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Select Picture", systemImage: "photo")
                }
                .onChange(of: selectedPhotoItem) { oldValue, newValue in
                    if let newValue {
                        Task {
                            if let data = try? await newValue.loadTransferable(type: Data.self) {
                                candidatePhoto = data
                            }
                        }
                    }
                }
                
                TextField("Social Media Links (comma-separated)", text: $socialMediaLinks)
                
                TextEditor(text: $notes)
                    .frame(height: 100)
                DatePicker("Date Entered", selection: $dateEntered, displayedComponents: .date)
            }
            
            Section {
                Button("Delete Candidate", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Candidate")
        .navigationBarItems(
            leading: Button("Cancel") {
                isPresented = false
            },
            trailing: Button("Save") {
                saveCandidate()
            }
        )
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationError?.localizedDescription ?? "Unknown error")
        }
        .alert("Avoid Candidate Flag", isPresented: $showingAvoidWarning) {
            TextField("Reason for change", text: $avoidFlagReason)
            Button("Cancel", role: .cancel) {
                // Reset to match the candidate's current value
                avoidCandidate = candidate.avoidCandidate
            }
            Button("Confirm") {
                // Reason will be saved when the candidate is saved
            }
        } message: {
            Text("Please provide a reason for changing the avoid flag status.")
        }
        .alert("Delete Candidate", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteCandidate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this candidate? This action cannot be undone.")
        }
        .overlay {
            if isProcessing {
                ProgressView("Saving...")
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
            }
        }
    }
    
    private func saveCandidate() {
        isProcessing = true
        
        Task {
            do {
                // Update the candidate with edited values
                candidate.name = name
                candidate.phoneNumber = phoneNumber
                candidate.email = email
                candidate.leadSource = leadSource
                candidate.referralName = leadSource == .referral ? referralName : nil
                candidate.yearsOfExperience = yearsOfExperience
                candidate.previousEmployers = Array(selectedEmployers)
                candidate.technicalFocus = Array(selectedFocus)
                candidate.technicianLevel = technicianLevel
                candidate.hiringStatus = hiringStatus
                
                // Validate the candidate
                try CandidateValidator.validate(candidate)
                
                // Update additional properties
                candidate.needsFollowUp = needsFollowUp
                candidate.isHotCandidate = isHotCandidate
                
                // Update position assignment
                candidate.position = selectedPosition
                
                // Only update avoid flag if it changed
                if candidate.avoidCandidate != avoidCandidate {
                    candidate.updateAvoidFlag(to: avoidCandidate, reason: avoidFlagReason)
                }
                
                candidate.conceptPayScale = conceptPayScale.isEmpty ? nil : conceptPayScale
                candidate.conceptPayDate = conceptPayDate
                candidate.needsHealthInsurance = needsHealthInsurance
                candidate.offerDetail = offerDetail.isEmpty ? nil : offerDetail
                candidate.offerDate = offerDate
                candidate.picture = candidatePhoto
                candidate.socialMediaLinks = socialMediaLinks.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                candidate.notes = notes
                
                // Close the form
                isPresented = false
                
            } catch let error as ValidationError {
                validationError = error
                showingValidationError = true
            } catch {
                validationError = ValidationError.missingRequiredField(error.localizedDescription)
                showingValidationError = true
            }
            
            isProcessing = false
        }
    }
    
    private func deleteCandidate() {
        // Remove the candidate from its position if assigned
        if let position = candidate.position {
            position.candidates.removeAll { $0.id == candidate.id }
        }
        
        // Delete the candidate and close the form
        modelContext.delete(candidate)
        isPresented = false
    }
}

#Preview {
    let candidate = Candidate(
        name: "John Doe",
        phoneNumber: "555-0123",
        email: "john@example.com",
        leadSource: .indeed,
        yearsOfExperience: 5,
        previousEmployers: [.dealership],
        technicalFocus: [.electrical],
        technicianLevel: .a
    )
    
    return CandidateDetailView(candidate: candidate)
}

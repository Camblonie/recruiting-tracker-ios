import SwiftUI
import SwiftData
import PhotosUI

struct CandidateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    // Form Fields
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var leadSource = LeadSource.indeed
    @State private var referralName = ""
    @State private var yearsOfExperience = 0
    @State private var selectedEmployers: Set<PreviousEmployer> = []
    @State private var selectedFocus: Set<TechnicalFocus> = []
    @State private var technicianLevel = TechnicianLevel.lubeTech
    @State private var hiringStatus = HiringStatus.ghosted
    @State private var needsFollowUp = false
    @State private var isHotCandidate = false
    @State private var avoidCandidate = false
    @State private var conceptPayScale = ""
    @State private var conceptPayDate = Date()
    @State private var needsHealthInsurance = false
    @State private var offerDetail = ""
    @State private var offerDate = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var candidatePhoto: Data?
    @State private var socialMediaLinks = ""
    @State private var notes = ""
    @State private var dateEntered = Date()
    
    // UI State
    @State private var showingValidationError = false
    @State private var validationError: ValidationError?
    @State private var showingAvoidWarning = false
    @State private var avoidFlagReason = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
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
                            if newValue {
                                showingAvoidWarning = true
                            }
                        }
                }
                
                Section("Compensation") {
                    TextField("Concept Pay Scale", text: $conceptPayScale)
                    DatePicker("Pay Scale Date", selection: $conceptPayDate, displayedComponents: .date)
                    Toggle("Needs Health Insurance", isOn: $needsHealthInsurance)
                }
                
                Section("Additional Information") {
                    TextField("Offer Details", text: $offerDetail)
                    DatePicker("Offer Date", selection: $offerDate, displayedComponents: .date)
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let candidatePhoto = candidatePhoto,
                           let uiImage = UIImage(data: candidatePhoto) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        } else {
                            Label("Add Photo", systemImage: "person.crop.square")
                        }
                    }
                    
                    TextField("Social Media Links", text: $socialMediaLinks)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                    DatePicker("Date Entered", selection: $dateEntered, displayedComponents: .date)
                }
            }
            .navigationTitle("New Candidate")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveCandidate()
                }
                .disabled(isProcessing)
            )
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        candidatePhoto = data
                    }
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationError?.localizedDescription ?? "Unknown error")
            }
            .alert("Avoid Candidate Flag", isPresented: $showingAvoidWarning) {
                TextField("Reason for avoiding", text: $avoidFlagReason)
                Button("Cancel", role: .cancel) {
                    avoidCandidate = false
                }
                Button("Confirm") {
                    // Reason will be saved when the candidate is saved
                }
            } message: {
                Text("Please provide a reason for marking this candidate as 'avoid'.")
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
    }
    
    private func saveCandidate() {
        isProcessing = true
        
        Task {
            do {
                let candidate = Candidate(
                    name: name,
                    phoneNumber: phoneNumber,
                    email: email,
                    leadSource: leadSource,
                    referralName: leadSource == .referral ? referralName : nil,
                    yearsOfExperience: yearsOfExperience,
                    previousEmployers: Array(selectedEmployers),
                    technicalFocus: Array(selectedFocus),
                    technicianLevel: technicianLevel,
                    hiringStatus: hiringStatus,
                    dateEntered: dateEntered
                )
                
                // Validate the candidate
                try CandidateValidator.validate(candidate)
                try CandidateValidator.checkForDuplicates(candidate: candidate, in: modelContext)
                
                // Update additional properties
                candidate.needsFollowUp = needsFollowUp
                candidate.isHotCandidate = isHotCandidate
                candidate.updateAvoidFlag(to: avoidCandidate, reason: avoidFlagReason)
                candidate.conceptPayScale = conceptPayScale
                candidate.conceptPayDate = conceptPayDate
                candidate.needsHealthInsurance = needsHealthInsurance
                candidate.offerDetail = offerDetail
                candidate.offerDate = offerDate
                candidate.picture = candidatePhoto
                candidate.socialMediaLinks = socialMediaLinks.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                candidate.notes = notes
                
                // Save to database
                modelContext.insert(candidate)
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
}

struct MultiSelectionView<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let options: T.AllCases
    @Binding var selected: Set<T>
    
    var body: some View {
        DisclosureGroup(title) {
            ForEach(Array(options), id: \.self) { option in
                Toggle(option.rawValue, isOn: Binding(
                    get: { selected.contains(option) },
                    set: { isSelected in
                        if isSelected {
                            selected.insert(option)
                        } else {
                            selected.remove(option)
                        }
                    }
                ))
            }
        }
    }
}

#Preview {
    CandidateFormView(isPresented: .constant(true))
}

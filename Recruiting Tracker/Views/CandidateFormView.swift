import SwiftUI
import SwiftData
import PhotosUI
import Combine

struct CandidateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @Query private var candidates: [Candidate]
    @Query private var positions: [Position]
    @Query private var companies: [Company]
    
    // Form Fields
    // Split name entry to improve data quality; composed on save to Candidate.name
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var leadSource: LeadSource?
    @State private var referralName = ""
    @State private var yearsOfExperience = 0
    @State private var selectedEmployers: Set<PreviousEmployer> = []
    @State private var selectedFocus: Set<TechnicalFocus> = []
    @State private var technicianLevel: TechnicianLevel?
    @State private var selectedPosition: Position?
    @State private var selectedCompany: Company?
    @State private var hiringStatus = HiringStatus.notContacted
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
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .accessibilityIdentifier("First Name")
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .accessibilityIdentifier("Last Name")
                    
                    PhoneTextField(text: $phoneNumber)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Picker("Lead Source", selection: $leadSource) {
                        Text("Select a lead source").tag(nil as LeadSource?)
                        ForEach(LeadSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source as LeadSource?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    if leadSource == .referral {
                        TextField("Referral Name", text: $referralName)
                    }
                }
                
                // Status earlier to reduce scrolling in tests and common flows
                Section("Status") {
                    Picker("Hiring Status", selection: $hiringStatus) {
                        Text("Select a status").tag(HiringStatus.notContacted)
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
                
                Section("Experience") {
                    Stepper("Years of Experience: \(yearsOfExperience)", value: $yearsOfExperience, in: 0...50)
                    
                    // Company selection (optional). Positions list is filtered by selected company when set.
                    if !companies.isEmpty {
                        Picker("Company", selection: $selectedCompany) {
                            Text("No company").tag(nil as Company?)
                            ForEach(companies) { company in
                                Text(company.name).tag(company as Company?)
                            }
                        }
                        .onChange(of: selectedCompany) { _, newValue in
                            // Clear position if it doesn't belong to the newly selected company
                            if let newCompany = newValue, let pos = selectedPosition,
                               !(newCompany.positions ?? []).contains(where: { $0 === pos }) {
                                selectedPosition = nil
                            }
                        }
                    }
                    let availablePositions: [Position] = (selectedCompany == nil) ? positions : (selectedCompany?.positions ?? [])
                    if !availablePositions.isEmpty {
                        Picker("Position", selection: $selectedPosition) {
                            Text("No position").tag(nil as Position?)
                            ForEach(availablePositions) { position in
                                Text(position.title).tag(position as Position?)
                            }
                        }
                    }
                    
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
                    
                    Picker("Skill Level", selection: $technicianLevel) {
                        Text("Select a level").tag(nil as TechnicianLevel?)
                        ForEach(TechnicianLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as TechnicianLevel?)
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveCandidate()
                }
                .disabled(isProcessing)
            )
            // Ensure high contrast navigation title/buttons for editing screens
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                TextField("Reason for change", text: $avoidFlagReason)
                Button("Cancel", role: .cancel) {
                    avoidCandidate = false
                }
                Button("Mark as Avoid") {
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
        
        Task { @MainActor in
            do {
                // Make sure required selections are made
                guard let leadSource = leadSource else {
                    throw ValidationError.missingRequiredField("Please select a Lead Source")
                }
                
                // Compose full name from first/last; trim to avoid trailing spaces when last name is empty
                let fullName = [firstName, lastName]
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                
                // Create the candidate; position may be set below after company logic
                let candidate = Candidate(
                    name: fullName,
                    phoneNumber: phoneNumber,
                    email: email,
                    leadSource: leadSource,
                    referralName: leadSource == .referral ? referralName : nil,
                    yearsOfExperience: yearsOfExperience,
                    previousEmployers: Array(selectedEmployers),
                    technicalFocus: Array(selectedFocus),
                    technicianLevel: technicianLevel ?? .unknown,
                    hiringStatus: hiringStatus,
                    position: selectedPosition,
                    dateEntered: dateEntered
                )
                
                // Validate the candidate
                try CandidateValidator.validate(candidate)
                try CandidateValidator.checkForDuplicates(candidate: candidate, in: modelContext)
                
                // Update additional properties
                // Debug: Log the state for UI tests
                print("[AddCandidate] name=\(fullName), needsFollowUp=\(needsFollowUp), isHot=\(isHotCandidate), avoid=\(avoidCandidate), lead=\(leadSource.rawValue)")
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
                
                // If a company is chosen but no position selected, create/find a generic position to associate
                if candidate.position == nil, let company = selectedCompany {
                    let defaultTitle = "General"
                    if let existing = (company.positions ?? []).first(where: { $0.title == defaultTitle }) {
                        candidate.position = existing
                    } else {
                        let created = Position(title: defaultTitle, positionDescription: "Auto-created")
                        if company.positions == nil { company.positions = [] }
                        company.positions?.append(created)
                        candidate.position = created
                    }
                }

                // Save to database
                modelContext.insert(candidate)
                // Persist changes so @Query in other views (e.g., Recruiting Tracker tab) observes the new record
                try modelContext.save()
                print("[AddCandidate] saved OK, id=\(candidate.id)")
                #if DEBUG
                let followCount = (try? modelContext.fetchCount(
                    FetchDescriptor<Candidate>(
                        predicate: #Predicate<Candidate> { $0.needsFollowUp }
                    )
                )) ?? -1
                print("[AddCandidate] followUpCount=\(followCount) saved.needs=\(candidate.needsFollowUp)")
                if candidate.needsFollowUp {
                    NotificationCenter.default.post(name: .didAddFollowUpCandidate, object: nil)
                }
                #endif
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

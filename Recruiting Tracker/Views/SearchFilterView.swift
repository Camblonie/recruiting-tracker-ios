import SwiftUI

struct SearchFilterView: View {
    @Binding var filter: SearchFilter
    @Binding var isPresented: Bool
    @State private var minimumExperience = ""
    @State private var maximumExperience = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    // Local selections for binding
    @State private var selectedLeadSources: Set<LeadSource> = []
    @State private var selectedPreviousEmployers: Set<PreviousEmployer> = []
    @State private var selectedTechnicalFocus: Set<TechnicalFocus> = []
    @State private var selectedTechnicianLevels: Set<TechnicianLevel> = []
    @State private var selectedHiringStatuses: Set<HiringStatus> = []

    var body: some View {
        NavigationView {
            Form {
                Section("Lead Source") {
                    MultiSelectionView(
                        title: "Lead Sources",
                        options: LeadSource.allCases,
                        selected: $selectedLeadSources
                    )
                }
                
                Section("Experience") {
                    TextField("Minimum Years", text: $minimumExperience)
                        .keyboardType(.numberPad)
                    
                    TextField("Maximum Years", text: $maximumExperience)
                        .keyboardType(.numberPad)
                    
                    MultiSelectionView(
                        title: "Technician Levels",
                        options: TechnicianLevel.allCases,
                        selected: $selectedTechnicianLevels
                    )
                    
                    MultiSelectionView(
                        title: "Technical Focus",
                        options: TechnicalFocus.allCases,
                        selected: $selectedTechnicalFocus
                    )
                    
                    MultiSelectionView(
                        title: "Previous Employers",
                        options: PreviousEmployer.allCases,
                        selected: $selectedPreviousEmployers
                    )
                }
                
                Section("Status") {
                    MultiSelectionView(
                        title: "Hiring Status",
                        options: HiringStatus.allCases,
                        selected: $selectedHiringStatuses
                    )
                    
                    Toggle("Hot Candidates Only", isOn: Binding(
                        get: { filter.isHotCandidate ?? false },
                        set: { filter.isHotCandidate = $0 ? true : nil }
                    ))
                    
                    Toggle("Needs Follow-up", isOn: Binding(
                        get: { filter.needsFollowUp ?? false },
                        set: { filter.needsFollowUp = $0 ? true : nil }
                    ))
                    
                    Toggle("Avoid List", isOn: Binding(
                        get: { filter.avoidCandidate ?? false },
                        set: { filter.avoidCandidate = $0 ? true : nil }
                    ))
                    
                    Toggle("Needs Insurance", isOn: Binding(
                        get: { filter.needsHealthInsurance ?? false },
                        set: { filter.needsHealthInsurance = $0 ? true : nil }
                    ))
                }
                
                Section("Date Range") {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
                
                Section {
                    Button("Reset Filters") {
                        filter = .empty
                        minimumExperience = ""
                        maximumExperience = ""
                        startDate = nil
                        endDate = nil
                        selectedLeadSources = []
                        selectedPreviousEmployers = []
                        selectedTechnicalFocus = []
                        selectedTechnicianLevels = []
                        selectedHiringStatuses = []
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Apply") {
                    // Commit local changes to filter
                    filter.leadSources = selectedLeadSources
                    filter.previousEmployers = selectedPreviousEmployers
                    filter.technicalFocus = selectedTechnicalFocus
                    filter.technicianLevels = selectedTechnicianLevels
                    filter.hiringStatuses = selectedHiringStatuses
                    filter.yearsOfExperienceMin = Int(minimumExperience)
                    filter.yearsOfExperienceMax = Int(maximumExperience)
                    if let start = startDate, let end = endDate {
                        filter.dateRange = start...end
                    }
                    isPresented = false
                }
            )
            .onAppear {
                // Initialize local states
                minimumExperience = filter.yearsOfExperienceMin.map(String.init) ?? ""
                maximumExperience = filter.yearsOfExperienceMax.map(String.init) ?? ""
                startDate = filter.dateRange?.lowerBound
                endDate = filter.dateRange?.upperBound
                selectedLeadSources = filter.leadSources
                selectedPreviousEmployers = filter.previousEmployers
                selectedTechnicalFocus = filter.technicalFocus
                selectedTechnicianLevels = filter.technicianLevels
                selectedHiringStatuses = filter.hiringStatuses
            }
        }
    }
}

#Preview {
    SearchFilterView(filter: .constant(.empty), isPresented: .constant(true))
}

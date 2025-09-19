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
            ZStack {
                Color.skyBlue.opacity(0.05).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Basic Filters Card
                        filterCard(title: "Quick Filters", icon: "slider.horizontal.3") {
                            VStack(alignment: .leading, spacing: 12) {
                                // Status Toggles
                                filterSectionHeader(title: "Candidate Status")
                                
                                statusToggle(
                                    title: "Hot Candidates Only",
                                    icon: "flame.fill",
                                    iconColor: .terracotta,
                                    isOn: Binding(
                                        get: { filter.isHotCandidate ?? false },
                                        set: { filter.isHotCandidate = $0 ? true : nil }
                                    )
                                )
                                
                                statusToggle(
                                    title: "Needs Follow-up",
                                    icon: "bell.fill",
                                    iconColor: .slate,
                                    isOn: Binding(
                                        get: { filter.needsFollowUp ?? false },
                                        set: { filter.needsFollowUp = $0 ? true : nil }
                                    )
                                )
                                
                                statusToggle(
                                    title: "Avoid List",
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: .red,
                                    isOn: Binding(
                                        get: { filter.avoidCandidate ?? false },
                                        set: { filter.avoidCandidate = $0 ? true : nil }
                                    )
                                )
                                
                                Divider().padding(.vertical, 4)
                                
                                // Experience Range
                                filterSectionHeader(title: "Experience")
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading) {
                                        Text("Min Years").font(.caption).foregroundColor(.secondary)
                                        TextField("Min", text: $minimumExperience)
                                            .keyboardType(.numberPad)
                                            .padding(8)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("Max Years").font(.caption).foregroundColor(.secondary)
                                        TextField("Max", text: $maximumExperience)
                                            .keyboardType(.numberPad)
                                            .padding(8)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                        }
                        
                        // Skill Levels Card
                        filterCard(title: "Skill Levels", icon: "person.fill") {
                            improvedMultiSelectionView(
                                options: TechnicianLevel.allCases,
                                selected: $selectedTechnicianLevels
                            )
                        }
                        
                        // Lead Sources Card
                        filterCard(title: "Lead Sources", icon: "link") {
                            improvedMultiSelectionView(
                                options: LeadSource.allCases,
                                selected: $selectedLeadSources
                            )
                        }
                        
                        // Previous Employers Card
                        filterCard(title: "Previous Employers", icon: "building.2") {
                            improvedMultiSelectionView(
                                options: PreviousEmployer.allCases,
                                selected: $selectedPreviousEmployers
                            )
                        }
                        
                        // Technical Focus Card
                        filterCard(title: "Technical Focus", icon: "hammer.fill") {
                            improvedMultiSelectionView(
                                options: TechnicalFocus.allCases,
                                selected: $selectedTechnicalFocus
                            )
                        }
                        
                        // Hiring Status Card
                        filterCard(title: "Hiring Status", icon: "checkmark.circle") {
                            improvedMultiSelectionView(
                                options: HiringStatus.allCases,
                                selected: $selectedHiringStatuses
                            )
                        }
                        
                        // Date Range Card
                        filterCard(title: "Date Entered Range", icon: "calendar") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Start Date").font(.subheadline)
                                    Spacer()
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { startDate ?? Date() },
                                            set: { startDate = $0 }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                }
                                
                                HStack {
                                    Text("End Date").font(.subheadline)
                                    Spacer()
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { endDate ?? Date() },
                                            set: { endDate = $0 }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                }
                            }
                        }
                        
                        // Reset Button
                        Button(action: {
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
                        }) {
                            Text("Reset All Filters")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.vertical)
                    }
                    .padding()
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
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
            // Ensure high-contrast header for filter editor
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

// MARK: - Helper Views
extension SearchFilterView {
    
    // Card layout for filter sections
    private func filterCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.slate)
                    .font(.headline)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.slate)
            }
            .padding(.bottom, 4)
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.slate.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Section header
    private func filterSectionHeader(title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundColor(.slate)
    }
    
    // Status toggle with icon
    private func statusToggle(title: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(8)
        .background(Color.skyBlue.opacity(0.05))
        .cornerRadius(8)
    }
    
    // Improved multi-selection view
    private func improvedMultiSelectionView<T: Hashable & CaseIterable & RawRepresentable>(
        options: T.AllCases,
        selected: Binding<Set<T>>
    ) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(options), id: \.self) { option in
                HStack {
                    if selected.wrappedValue.contains(option) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.slate)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                    
                    Text(option.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.wrappedValue.contains(option) {
                        selected.wrappedValue.remove(option)
                    } else {
                        selected.wrappedValue.insert(option)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

// Preview
struct SearchFilterView_Previews: PreviewProvider {
    static var previews: some View {
        SearchFilterView(filter: .constant(.empty), isPresented: .constant(true))
    }
}

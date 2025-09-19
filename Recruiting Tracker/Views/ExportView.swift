import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = ExportConfiguration()
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var searchFilter: SearchFilter?
    @State private var sortOption: SortOption?
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showingError = false
    
    private let availableFields = [
        // Preferred split name fields
        "First Name",
        "Last Name",
        // Legacy combined name (kept for backwards compatibility)
        "Name",
        // Contact info
        "Email",
        "Phone",
        // Source and profile
        "Lead Source",
        "Company",
        "Referral",
        "Experience",
        "Skill Level",
        "Previous Employers",
        "Technical Focus",
        // Status
        "Hiring Status",
        "Contacted",
        "Hot Candidate",
        "Needs Follow-up",
        "Avoid",
        // Compensation & misc
        "Pay Scale",
        "Needs Insurance",
        "Notes",
        "Date Entered"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $configuration.format) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                }
                
                Section("Fields to Include") {
                    ForEach(availableFields, id: \.self) { field in
                        Toggle(field, isOn: Binding(
                            get: { configuration.includeFields.contains(field) },
                            set: { isSelected in
                                if isSelected {
                                    configuration.includeFields.insert(field)
                                } else {
                                    configuration.includeFields.remove(field)
                                }
                            }
                        ))
                    }
                    
                    Button("Select All") {
                        configuration.includeFields = Set(availableFields)
                    }
                    
                    Button("Clear All") {
                        configuration.includeFields.removeAll()
                    }
                }
                
                Section("Date Range") {
                    Toggle("Filter by Date", isOn: Binding(
                        get: { startDate != nil },
                        set: { isEnabled in
                            if isEnabled {
                                startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())
                                endDate = Date()
                            } else {
                                startDate = nil
                                endDate = nil
                            }
                        }
                    ))
                    
                    if startDate != nil {
                        DatePicker("Start Date", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ), displayedComponents: .date)
                        
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section("Filters") {
                    NavigationLink("Apply Search Filters") {
                        SearchFilterView(
                            filter: Binding(
                                get: { searchFilter ?? SearchFilter.empty },
                                set: { searchFilter = $0 }
                            ),
                            isPresented: .constant(false)
                        )
                    }
                    
                    if searchFilter != nil {
                        Button("Clear Filters", role: .destructive) {
                            searchFilter = nil
                        }
                    }
                }
                
                Section("Sorting") {
                    Picker("Sort By", selection: Binding(
                        get: { sortOption ?? .nameAsc },
                        set: { sortOption = $0 }
                    )) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Export") {
                    exportData()
                }
                .disabled(configuration.includeFields.isEmpty || isExporting)
            )
            // Ensure high contrast navigation title/buttons for editing screens
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError?.localizedDescription ?? "Unknown error occurred")
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        // Update configuration
        if let start = startDate, let end = endDate {
            configuration.dateRange = start...end
        }
        configuration.filter = searchFilter
        configuration.sortOption = sortOption
        
        Task {
            do {
                let exporter = DataExporter(modelContext: modelContext)
                let data = try exporter.exportData(config: configuration)
                
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("export")
                    .appendingPathExtension(configuration.format.fileExtension)
                
                try data.write(to: tempURL)
                
                // Share file
                await shareFile(at: tempURL)
                
                isExporting = false
                dismiss()
                
            } catch {
                exportError = error
                showingError = true
                isExporting = false
            }
        }
    }
    
    private func shareFile(at url: URL) async {
        await MainActor.run {
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: url)
                }
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

#Preview {
    ExportView()
}

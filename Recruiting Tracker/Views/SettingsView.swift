import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var companies: [Company]
    @Query private var candidates: [Candidate]
    @Query private var positions: [Position]
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingExportOptions = false
    @State private var exportFormat = ExportFormat.text
    @State private var showingCompanyEditor = false
    // Multi-company management
    @State private var showingAddCompany = false
    @State private var newCompanyName = ""
    @State private var companyToEdit: Company?
    // Debug
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var showDebugResetAlert = false
    @State private var showDebugDeleteAlert = false
    @State private var showingPositionManager = false
    @State private var newPositionTitle = ""
    @State private var newPositionDescription = ""
    @State private var showingAddPosition = false
    @State private var showingExport = false
    // CSV import
    @State private var showingCSVImporter = false
    @State private var showingImportSummary = false
    @State private var importSummaryMessage = ""
    @State private var showMappingSheet = false
    @State private var pendingCSVData: Data?
    @State private var csvHeaders: [String] = []
    @State private var initialMapping: [CSVImporter.Field: Int] = [:]
    
    var company: Company? {
        companies.first
    }
    
    enum ExportFormat {
        case text
        case csv
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Companies") {
                    ForEach(companies) { co in
                        HStack {
                            CompanyInfoRow(company: co)
                            Spacer()
                            Button("Edit") {
                                companyToEdit = co
                                showingCompanyEditor = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: deleteCompanies)
                    
                    Button("Add Company") {
                        showingAddCompany = true
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Position Management") {
                    ForEach(positions) { position in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(position.title)
                                    .font(.headline)
                                
                                if !position.positionDescription.isEmpty {
                                    Text(position.positionDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(position.candidates.count) candidates")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deletePositions)
                    
                    Button("Add Position") {
                        showingAddPosition = true
                    }
                }
                
                Section("Data Management") {
                    Button("Export Database") {
                        showingExportOptions = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Export Data Settings") {
                        showingExport = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Import CSV") { showingCSVImporter = true }
                    .foregroundColor(.blue)
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }

                #if DEBUG
                Section("Debug") {
                    Button("Reset Onboarding Flag") {
                        showDebugResetAlert = true
                    }
                    .foregroundColor(.blue)

                    Button("Delete All Companies") {
                        showDebugDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedItem = nil
                        if let company = company {
                            company.icon = data
                        }
                    }
                }
            }
            .onAppear {
                // Ensure navigation bar title text is white
                let navBarAppearance = UINavigationBar.appearance()
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                if company != nil {
                    selectedItem = nil
                }
            }
            .confirmationDialog(
                "Export Format",
                isPresented: $showingExportOptions,
                titleVisibility: .visible
            ) {
                Button("Text Format") {
                    exportDatabase(.text)
                }
                Button("CSV Format") {
                    exportDatabase(.csv)
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingCompanyEditor) {
                // Edit the selected company
                if let target = companyToEdit {
                    CompanyEditorView(company: target)
                }
            }
            .sheet(isPresented: $showingAddCompany) {
                // Simple UI to add a new company by name; logo can be added later via editor
                NavigationView {
                    Form {
                        Section("New Company") {
                            TextField("Company Name", text: $newCompanyName)
                        }
                    }
                    .navigationTitle("Add Company")
                    .navigationBarTitleDisplayMode(.inline)
                    // High-contrast header for add company sheet
                    .toolbarBackground(Color.slate, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddCompany = false
                            newCompanyName = ""
                        },
                        trailing: Button("Save") {
                            saveNewCompany()
                        }
                        .disabled(newCompanyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
            .sheet(isPresented: $showingAddPosition) {
                NavigationView {
                    Form {
                        Section("New Position") {
                            TextField("Position Title", text: $newPositionTitle)
                            
                            TextField("Position Description", text: $newPositionDescription, axis: .vertical)
                                .lineLimit(4)
                        }
                    }
                    .navigationTitle("Add Position")
                    .navigationBarTitleDisplayMode(.inline)
                    // High-contrast header for add position sheet
                    .toolbarBackground(Color.slate, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddPosition = false
                            newPositionTitle = ""
                            newPositionDescription = ""
                        },
                        trailing: Button("Save") {
                            saveNewPosition()
                        }
                        .disabled(newPositionTitle.isEmpty)
                    )
                }
            }
            .sheet(isPresented: $showingExport) { ExportView() }
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [UTType.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    prepareCSVImport(from: url)
                case .failure(let error):
                    importSummaryMessage = "Import canceled or failed: \(error.localizedDescription)"
                    showingImportSummary = true
                }
            }
            .sheet(isPresented: $showMappingSheet) {
                CSVMappingView(
                    headers: csvHeaders,
                    initialMapping: initialMapping,
                    initialOptions: .default,
                    onCancel: { showMappingSheet = false },
                    onConfirm: { mapping, options in
                        showMappingSheet = false
                        guard let data = pendingCSVData else { return }
                        let result = CSVImporter.importCandidates(csvData: data, into: modelContext, mapping: mapping, options: options)
                        var msg = "Imported: \(result.imported)\nSkipped: \(result.skipped)"
                        if !result.errors.isEmpty {
                            msg += "\nErrors (\(result.errors.count)):\n\(result.errors.prefix(5).joined(separator: "\n"))"
                            if result.errors.count > 5 { msg += "\n…" }
                        }
                        importSummaryMessage = msg
                        showingImportSummary = true
                        pendingCSVData = nil
                        csvHeaders = []
                        initialMapping = [:]
                    }
                )
            }
            .alert("Import Summary", isPresented: $showingImportSummary) {
                Button("Copy Details") {
                    UIPasteboard.general.string = importSummaryMessage
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(importSummaryMessage)
            }
            #if DEBUG
            .alert("Reset Onboarding", isPresented: $showDebugResetAlert) {
                Button("Reset", role: .destructive) {
                    didCompleteOnboarding = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Sets didCompleteOnboarding = false. Onboarding will show only if there are no companies.")
            }
            .alert("Delete All Companies", isPresented: $showDebugDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteAllCompanies()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all companies and their positions. Candidates will be detached from those positions.")
            }
            #endif
        }
    }
    
    // MARK: - CSV Import
    private func prepareCSVImport(from url: URL) {
        // Access security-scoped resource if needed
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            // Build a preview and default mapping, then show mapping UI
            if let preview = CSVImporter.preview(csvData: data) {
                // Proceed to mapping even if we couldn't detect data rows yet; importer will emit diagnostics
                pendingCSVData = data
                csvHeaders = preview.headers
                initialMapping = CSVImporter.defaultMappingIndices(headers: preview.headers)
                // Present mapping sheet on next run loop to avoid race with the fileImporter dismissal
                DispatchQueue.main.async {
                    showMappingSheet = true
                }
            } else {
                importSummaryMessage = "Invalid CSV format or encoding."
                showingImportSummary = true
            }
        } catch {
            importSummaryMessage = "Failed to read file: \(error.localizedDescription)"
            showingImportSummary = true
        }
    }

    private func saveNewPosition() {
        guard !newPositionTitle.isEmpty else { return }
        
        if let company = company {
            let position = Position(title: newPositionTitle, positionDescription: newPositionDescription)
            company.positions.append(position)
            
            // Clear form
            newPositionTitle = ""
            newPositionDescription = ""
            showingAddPosition = false
        }
    }
    
    private func saveNewCompany() {
        let trimmed = newCompanyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let co = Company(name: trimmed)
        modelContext.insert(co)
        newCompanyName = ""
        showingAddCompany = false
    }
    
    private func deletePositions(at offsets: IndexSet) {
        for index in offsets {
            let position = positions[index]
            
            // Remove the position from any candidates
            for candidate in position.candidates {
                candidate.position = nil
            }
            
            // Delete the position
            modelContext.delete(position)
        }
    }
    
    private func deleteCompanies(at offsets: IndexSet) {
        for index in offsets {
            let co = companies[index]
            // Detach candidates from positions owned by this company, delete positions, then delete company
            for pos in co.positions {
                for cand in pos.candidates {
                    cand.position = nil
                }
                modelContext.delete(pos)
            }
            modelContext.delete(co)
        }
    }
    
    #if DEBUG
    private func deleteAllCompanies() {
        for co in companies {
            for pos in co.positions {
                for cand in pos.candidates {
                    cand.position = nil
                }
                modelContext.delete(pos)
            }
            modelContext.delete(co)
        }
    }
    #endif
    
    private func exportDatabase(_ format: ExportFormat) {
        let exportString: String
        let fileName: String
        
        switch format {
        case .text:
            exportString = DatabaseExporter.exportDatabase(candidates: candidates)
            fileName = "recruiting_database_export.txt"
        case .csv:
            exportString = DatabaseExporter.exportToCSV(candidates: candidates, companies: companies)
            fileName = "recruiting_database_export.csv"
        }
        
        guard let data = exportString.data(using: .utf8) else { return }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct CompanyInfoRow: View {
    let company: Company
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = company.icon,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
            }
            
            Text(company.name)
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}

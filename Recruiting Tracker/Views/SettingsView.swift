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
    @AppStorage("useCloudSync") private var useCloudSync = false
    
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
    // Share sheet for choosing an export destination/app
    @State private var showingExportShare = false
    @State private var exportShareURL: URL?
    // Cloud Sync
    @State private var showCloudSyncInfo = false
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

// UIKit document picker wrapper to export a file to user-chosen destination (Files app, iCloud Drive, etc.).
struct DocumentExportPicker: UIViewControllerRepresentable {
    let url: URL
    var onFinish: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Present as export (copy) so the temporary file remains until the user completes the operation
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.delegate = context.coordinator
        controller.shouldShowFileExtensions = true
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentExportPicker
        init(_ parent: DocumentExportPicker) { self.parent = parent }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onFinish()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onFinish()
        }
    }
}
    
    enum ExportFormat {
        case text
        case csv
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Cloud Sync") {
                    Toggle(isOn: $useCloudSync) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable iCloud Sync")
                            Text("Requires iOS 18+, iCloud/CloudKit entitlements, and app relaunch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: useCloudSync) { _, _ in
                        // Inform the user that a relaunch is needed and entitlements must be configured
                        showCloudSyncInfo = true
                    }

                    LabeledContent("Status", value: useCloudSync ? "On (takes effect next launch)" : "Off (local only)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                            
                            Text("\(position.candidates?.count ?? 0) candidates")
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
            // Use a sheet instead of confirmationDialog so the chooser does not anchor to the nav header
            .sheet(isPresented: $showingExportOptions) {
                ExportFormatSheet(
                    onSelectText: {
                        showingExportOptions = false
                        exportDatabase(.text)
                    },
                    onSelectCSV: {
                        showingExportOptions = false
                        exportDatabase(.csv)
                    },
                    onCancel: {
                        showingExportOptions = false
                    }
                )
            }
            .sheet(isPresented: $showingCompanyEditor) {
                // Edit the selected company
                if let target = companyToEdit {
                    CompanyEditorView(company: target)
                }
            }
            .alert("Cloud Sync", isPresented: $showCloudSyncInfo) {
                Button("OK") {}
            } message: {
                Text("Cloud Sync will initialize on next app launch when iCloud/CloudKit is enabled in Signing & Capabilities with container iCloud.com.camblonie.RecruitingTracker. If entitlements are missing, the app will fall back to local storage.")
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
            .sheet(isPresented: $showingExportShare) {
                if let url = exportShareURL {
                    ShareSheet(activityItems: [url])
                }
            }
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
            if company.positions == nil { company.positions = [] }
            company.positions?.append(position)
            
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
            for candidate in position.candidates ?? [] {
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
            for pos in (co.positions ?? []) {
                for cand in pos.candidates ?? [] {
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
            for pos in (co.positions ?? []) {
                for cand in pos.candidates ?? [] {
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

        // Defer slightly so the format sheet fully dismisses before showing share UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            exportShareURL = url
            showingExportShare = true
        }
    }

    /// Find the top-most view controller on the active foreground UIWindowScene.
    /// This helps ensure modal presentations appear above all other content.
    private func topMostViewController() -> UIViewController? {
        // Find the active foreground scene
        let scenes = UIApplication.shared.connectedScenes
        let activeScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        // Get key window (fallback to first window if key not found)
        let window = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first
        guard var top = window?.rootViewController else { return nil }
        // Descend through presented/navigation/tab containers
        while true {
            if let presented = top.presentedViewController {
                top = presented
            } else if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
                top = visible
            } else if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
                top = selected
            } else {
                break
            }
        }
        return top
    }
}

// Lightweight sheet used to choose export format without anchoring to the nav bar header.
struct ExportFormatSheet: View {
    let onSelectText: () -> Void
    let onSelectCSV: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                List {
                    Section("Choose Format") {
                        Button(action: onSelectText) {
                            Label("Text Format", systemImage: "doc.text")
                        }
                        Button(action: onSelectCSV) {
                            Label("CSV Format", systemImage: "tablecells")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Export Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            // High-contrast header consistent with the app's style
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        // Present compactly so it doesn't feel intrusive
        .presentationDetents([.fraction(0.35), .medium])
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

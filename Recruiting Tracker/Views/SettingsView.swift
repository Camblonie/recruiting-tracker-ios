import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var companies: [Company]
    @Query private var candidates: [Candidate]
    
    @State private var companyName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var companyIcon: Data?
    @State private var showingExportOptions = false
    @State private var exportFormat = ExportFormat.text
    @State private var showingCompanyEditor = false
    @State private var showingExport = false
    @State private var showingDeleteConfirmation = false
    
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
                Section("Company Information") {
                    if let currentCompany = company {
                        CompanyInfoRow(company: currentCompany)
                    }
                    
                    TextField("Company Name", text: $companyName)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let companyIcon = companyIcon,
                           let uiImage = UIImage(data: companyIcon) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        } else {
                            Label("Select Company Icon", systemImage: "building.2")
                        }
                    }
                    
                    Button("Edit Company Info") {
                        showingCompanyEditor = true
                    }
                }
                
                Section("Data Management") {
                    Button("Export Database") {
                        showingExportOptions = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Export Data") {
                        showingExport = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Delete All Data", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        companyIcon = data
                        if let company = company {
                            company.icon = data
                        }
                    }
                }
            }
            .onAppear {
                if let company = company {
                    companyName = company.name
                    companyIcon = company.icon
                }
            }
            .onChange(of: companyName) { oldValue, newValue in
                if let company = company {
                    company.name = newValue
                } else {
                    let newCompany = Company(name: newValue, icon: companyIcon)
                    modelContext.insert(newCompany)
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
                if let currentCompany = company {
                    CompanyEditorView(company: currentCompany)
                }
            }
            .sheet(isPresented: $showingExport) {
                ExportView()
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all data? This action cannot be undone.")
            }
        }
    }
    
    private func exportDatabase(_ format: ExportFormat) {
        let exportString: String
        let fileName: String
        
        switch format {
        case .text:
            exportString = DatabaseExporter.exportDatabase(candidates: candidates)
            fileName = "recruiting_database_export.txt"
        case .csv:
            exportString = DatabaseExporter.exportToCSV(candidates: candidates)
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
    
    private func deleteAllData() {
        do {
            try modelContext.delete(model: Company.self)
            try modelContext.delete(model: Candidate.self)
        } catch {
            print("Error deleting data: \(error)")
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

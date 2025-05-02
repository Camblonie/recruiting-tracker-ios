import SwiftUI
import UniformTypeIdentifiers

struct FileAttachmentView: View {
    @Environment(\.modelContext) private var modelContext
    let candidate: Candidate
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    isImporting = true
                }) {
                    Label("Add Document", systemImage: "doc.badge.plus")
                }
            }
            
            if !candidate.attachedFiles.isEmpty {
                Section("Attached Files") {
                    ForEach(candidate.attachedFiles) { file in
                        FileRow(file: file)
                    }
                    .onDelete(perform: deleteFiles)
                }
            }
        }
        .navigationTitle("Documents")
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                
                let attachment = CandidateFile(
                    fileName: fileName,
                    fileData: data,
                    fileType: "pdf"
                )
                candidate.attachedFiles.append(attachment)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = candidate.attachedFiles[index]
            modelContext.delete(file)
            candidate.attachedFiles.remove(at: index)
        }
    }
}

struct FileRow: View {
    let file: CandidateFile
    @State private var isSharing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(file.fileName)
                    .font(.headline)
                Text(file.dateAdded.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                isSharing = true
            }) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(activityItems: [file.fileData])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

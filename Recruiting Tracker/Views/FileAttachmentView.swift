import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import UIKit

struct FileAttachmentView: View {
    @Environment(\.modelContext) private var modelContext
    let candidate: Candidate
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Max allowed file size (10 MB) to keep SwiftData store lean
    private let maxFileSizeBytes = 10 * 1024 * 1024
    
    // Allowed content types for import (PDF, images, and DOCX)
    private var allowedContentTypes: [UTType] {
        var types: [UTType] = [.pdf, .image]
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        return types
    }
    
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
            allowedContentTypes: allowedContentTypes,
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
                
                // Determine content type and size, enforce limits, and read data
                let fileName = url.lastPathComponent
                let ext = url.pathExtension
                let contentType = UTType(filenameExtension: ext)
                let typeIdentifier = contentType?.identifier ?? ext.lowercased()
                
                // Basic size check to avoid bloating the store
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resourceValues.fileSize ?? 0
                if fileSize > maxFileSizeBytes {
                    throw NSError(
                        domain: "",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "File \(fileName) exceeds the 10 MB size limit."]
                    )
                }
                
                // Read data and create attachment
                let data = try Data(contentsOf: url)
                let attachment = CandidateFile(
                    fileName: fileName,
                    fileData: data,
                    fileType: typeIdentifier
                )
                // Append to relationship array
                candidate.attachedFiles.append(attachment)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        // Delete each file from context and remove from relationship
        for index in offsets.sorted(by: >) {
            let file = candidate.attachedFiles[index]
            modelContext.delete(file)
            candidate.attachedFiles.remove(at: index)
        }
    }
}

struct FileRow: View {
    let file: CandidateFile
    @State private var isSharing = false
    @State private var isPreviewing = false
    @State private var previewURL: URL? = nil
    
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
            
            // Share via temporary file URL (better interoperability)
            Button(action: {
                if let url = createTempFileURL() {
                    previewURL = url // reuse for share
                    isSharing = true
                }
            }) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = createTempFileURL() {
                previewURL = url
                isPreviewing = true
            }
        }
        .sheet(isPresented: $isSharing) {
            if let url = previewURL { // share URL when available
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $isPreviewing) {
            if let url = previewURL {
                QuickLookPreview(url: url)
            }
        }
    }
    
    /// Create a temporary file URL for preview/sharing
    private func createTempFileURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(file.fileName)
        do {
            try file.fileData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
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

// Quick Look preview for local file URLs
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as NSURL
        }
    }
}

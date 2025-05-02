import Foundation
import SwiftData
import UniformTypeIdentifiers

/**
 Represents a file document attached to a candidate record.
 Examples include resumes, cover letters, certifications, etc.
 */
@Model
final class CandidateFile {
    // MARK: - Properties
    var id: String
    var fileName: String
    var fileData: Data
    var fileType: String
    var dateAdded: Date
    
    // MARK: - Relationships
    @Relationship var candidate: Candidate?
    
    // MARK: - Initialization
    init(fileName: String, fileData: Data, fileType: String, candidate: Candidate? = nil) {
        self.id = UUID().uuidString
        self.fileName = fileName
        self.fileData = fileData
        self.fileType = fileType
        self.dateAdded = Date()
        self.candidate = candidate
    }
    
    // MARK: - File Type Helpers
    var fileExtension: String {
        (fileName as NSString).pathExtension
    }
    
    var displayName: String {
        (fileName as NSString).deletingPathExtension
    }
    
    var contentType: UTType? {
        UTType(filenameExtension: fileExtension)
    }
    
    var isImage: Bool {
        contentType?.conforms(to: .image) ?? false
    }
    
    var isPDF: Bool {
        contentType?.conforms(to: .pdf) ?? false
    }
}

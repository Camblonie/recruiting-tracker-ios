import Foundation
import SwiftData
import UniformTypeIdentifiers
import UIKit
import PDFKit

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF"
    case xlsx = "Excel"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        case .xlsx: return "xlsx"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        case .pdf: return .pdf
        case .xlsx: return UTType("org.openxmlformats.spreadsheetml.sheet")!
        }
    }
}

struct ExportConfiguration {
    var format: ExportFormat = .csv
    var includeFields: Set<String> = []
    var dateRange: ClosedRange<Date>?
    var filter: SearchFilter?
    var sortOption: SortOption?
}

class DataExporter {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func exportData(config: ExportConfiguration) throws -> Data {
        // Fetch candidates based on configuration
        var descriptor = FetchDescriptor<Candidate>()
        
        // Apply date range filter
        if let dateRange = config.dateRange {
            descriptor.predicate = #Predicate<Candidate> { candidate in
                dateRange.contains(candidate.dateEntered)
            }
        }
        
        // Apply search filter if present
        if let searchFilter = config.filter {
            // Apply search filter predicate
            descriptor.predicate = searchFilter.buildPredicate()
        }
        
        // Apply sorting
        if let sortOption = config.sortOption, let searchFilter = config.filter {
            descriptor.sortBy = [searchFilter.sortDescriptor(option: sortOption)]
        }
        
        let candidates = try modelContext.fetch(descriptor)
        
        // Export based on format
        switch config.format {
        case .csv:
            return try exportToCSV(candidates: candidates, fields: config.includeFields)
        case .json:
            return try exportToJSON(candidates: candidates, fields: config.includeFields)
        case .pdf:
            return try exportToPDF(candidates: candidates, fields: config.includeFields)
        case .xlsx:
            return try exportToExcel(candidates: candidates, fields: config.includeFields)
        }
    }
    
    private func exportToCSV(candidates: [Candidate], fields: Set<String>) throws -> Data {
        var csvString = ""
        let headers = fields.isEmpty ? defaultHeaders : Array(fields)
        
        // Add headers
        csvString += headers.joined(separator: ",") + "\n"
        
        // Add data rows
        for candidate in candidates {
            let row = headers.map { header in
                let value = self.getValue(for: header, from: candidate)
                return escapeCSVField(value)
            }
            csvString += row.joined(separator: ",") + "\n"
        }
        
        return csvString.data(using: .utf8)!
    }
    
    private func exportToJSON(candidates: [Candidate], fields: Set<String>) throws -> Data {
        let headers = fields.isEmpty ? defaultHeaders : Array(fields)
        
        let jsonArray = candidates.map { candidate in
            headers.reduce(into: [String: Any]()) { dict, header in
                dict[header] = self.getValue(for: header, from: candidate)
            }
        }
        
        return try JSONSerialization.data(
            withJSONObject: jsonArray,
            options: [.prettyPrinted]
        )
    }
    
    private func exportToPDF(candidates: [Candidate], fields: Set<String>) throws -> Data {
        let headers = fields.isEmpty ? defaultHeaders : Array(fields)
        
        // Create PDF document
        let pdfMetadata = [
            kCGPDFContextCreator: "Recruiting Tracker" as CFString,
            kCGPDFContextAuthor: "Recruiting Tracker App" as CFString
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let titleAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)
            ]
            let headerAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12)
            ]
            let textAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10)
            ]
            
            // Draw title
            let title = "Candidate Export"
            title.draw(at: CGPoint(x: 36, y: 36), withAttributes: titleAttributes)
            
            // Draw headers
            var yPosition: CGFloat = 72
            let xPosition: CGFloat = 36
            let columnWidth: CGFloat = 100
            
            for (index, header) in headers.enumerated() {
                let x = xPosition + CGFloat(index) * columnWidth
                header.draw(at: CGPoint(x: x, y: yPosition), withAttributes: headerAttributes)
            }
            
            // Draw data
            yPosition += 20
            for candidate in candidates {
                if yPosition > pageRect.height - 72 {
                    context.beginPage()
                    yPosition = 36
                }
                
                for (index, header) in headers.enumerated() {
                    let value = getValue(for: header, from: candidate)
                    let x = xPosition + CGFloat(index) * columnWidth
                    value.draw(at: CGPoint(x: x, y: yPosition), withAttributes: textAttributes)
                }
                
                yPosition += 15
            }
        }
        
        return data
    }
    
    private func exportToExcel(candidates: [Candidate], fields: Set<String>) throws -> Data {
        // For Excel export, we'll create a CSV that Excel can open
        // In a production app, you would want to use a proper Excel library
        return try exportToCSV(candidates: candidates, fields: fields)
    }
    
    private func getValue(for field: String, from candidate: Candidate) -> String {
        switch field {
        case "First Name":
            let parts = splitName(candidate.name)
            return parts.first
        case "Last Name":
            let parts = splitName(candidate.name)
            return parts.last
        case "Name":
            // Backwards-compatibility if a consumer selects legacy field
            return candidate.name
        case "Email":
            return candidate.email
        case "Phone":
            return candidate.phoneNumber
        case "Lead Source":
            return candidate.leadSource.rawValue
        case "Referral":
            return candidate.referralName ?? ""
        case "Company":
            return companyName(for: candidate)
        case "Experience":
            return "\(candidate.yearsOfExperience) years"
        case "Skill Level":
            return candidate.technicianLevel.rawValue
        case "Tech Level": // legacy label support
            return candidate.technicianLevel.rawValue
        case "Previous Employers":
            return candidate.previousEmployers.map(\.rawValue).joined(separator: "; ")
        case "Technical Focus":
            return candidate.technicalFocus.map(\.rawValue).joined(separator: "; ")
        case "Hiring Status":
            return candidate.hiringStatus.rawValue
        case "Contacted":
            return candidate.hiringStatus == .notContacted ? "No" : "Yes"
        case "Hot Candidate":
            return candidate.isHotCandidate ? "Yes" : "No"
        case "Needs Follow-up":
            return candidate.needsFollowUp ? "Yes" : "No"
        case "Avoid":
            return candidate.avoidCandidate ? "Yes" : "No"
        case "Pay Scale":
            return candidate.conceptPayScale ?? ""
        case "Needs Insurance":
            return candidate.needsHealthInsurance ? "Yes" : "No"
        case "Notes":
            return candidate.notes
        case "Date Entered":
            return candidate.dateEntered.formatted(date: .numeric, time: .omitted)
        default:
            return ""
        }
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    private var defaultHeaders: [String] {
        // Default order prioritizes split name fields, then email/phone for common workflows
        [
            "First Name",
            "Last Name",
            "Email",
            "Phone",
            "Lead Source",
            "Company",
            "Referral",
            "Experience",
            "Skill Level",
            "Previous Employers",
            "Technical Focus",
            "Hiring Status",
            "Contacted",
            "Hot Candidate",
            "Needs Follow-up",
            "Avoid",
            "Pay Scale",
            "Needs Insurance",
            "Notes",
            "Date Entered"
        ]
    }

    // MARK: - Helpers
    private func companyName(for candidate: Candidate) -> String {
        guard let pos = candidate.position else { return "" }
        // Fetch companies and locate the one owning this position
        // Keep it simple; datasets are expected to be modest
        let descriptor = FetchDescriptor<Company>()
        if let companies = try? modelContext.fetch(descriptor) {
            if let company = companies.first(where: { $0.positions.contains(where: { $0 === pos }) }) {
                return company.name
            }
        }
        return ""
    }

    private func splitName(_ full: String) -> (first: String, last: String) {
        let comps = full.split(whereSeparator: { $0.isWhitespace })
        guard let first = comps.first else { return (full, "") }
        if comps.count == 1 { return (String(first), "") }
        let last = comps.dropFirst().joined(separator: " ")
        return (String(first), last)
    }
}

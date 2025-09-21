import Foundation
import SwiftData

class DatabaseExporter {
    static func exportDatabase(candidates: [Candidate]) -> String {
        var export = "Recruiting Tracker Database Export\n"
        export += "Generated: \(Date().formatted())\n"
        export += "Total Candidates: \(candidates.count)\n\n"
        
        for (index, candidate) in candidates.enumerated() {
            export += "Candidate #\(index + 1)\n"
            export += "==================\n"
            export += candidate.exportData()
            export += "\n\n"
        }
        
        return export
    }
    
    static func exportToCSV(candidates: [Candidate], companies: [Company]) -> String {
        // Updated schema includes Company and uses Skill Level label; booleans as Yes/No
        var csv = "First Name,Last Name,Email,Phone,Lead Source,Company,Years Experience,Skill Level,Hiring Status,Contacted,Hot Candidate,Needs Follow-up,Needs Insurance,Notes,Date Entered\n"
        
        for candidate in candidates {
            let parts = splitName(candidate.name)
            let contacted = candidate.hiringStatus == .notContacted ? "No" : "Yes"
            let companyName = companyName(for: candidate, companies: companies)
            csv += "\"\(parts.first)\"," // First Name
            csv += "\"\(parts.last)\"," // Last Name
            csv += "\"\(candidate.email)\"," // Email
            csv += "\"\(candidate.phoneNumber)\"," // Phone
            csv += "\"\(candidate.leadSource.rawValue)\"," // Lead Source
            csv += "\"\(companyName)\"," // Company
            csv += "\(candidate.yearsOfExperience)," // Years Experience
            csv += "\"\(candidate.technicianLevel.rawValue)\"," // Skill Level
            csv += "\"\(candidate.hiringStatus.rawValue)\"," // Hiring Status
            csv += "\"\(contacted)\"," // Contacted
            csv += "\"\(candidate.isHotCandidate ? "Yes" : "No")\"," // Hot Candidate
            csv += "\"\(candidate.needsFollowUp ? "Yes" : "No")\"," // Needs Follow-up
            csv += "\"\(candidate.needsHealthInsurance ? "Yes" : "No")\"," // Needs Insurance
            csv += "\"\(candidate.notes.replacingOccurrences(of: "\"", with: "\"\""))\"," // Notes escaped
            csv += "\"\(candidate.dateEntered.formatted(date: .numeric, time: .omitted))\"\n" // Date Entered
        }
        
        return csv
    }

    // Split a full name into first and last parts for export convenience
    private static func splitName(_ full: String) -> (first: String, last: String) {
        let comps = full.split(whereSeparator: { $0.isWhitespace })
        guard let first = comps.first else { return (full, "") }
        if comps.count == 1 { return (String(first), "") }
        let last = comps.dropFirst().joined(separator: " ")
        return (String(first), last)
    }

    private static func companyName(for candidate: Candidate, companies: [Company]) -> String {
        guard let pos = candidate.position else { return "" }
        if let co = companies.first(where: { ($0.positions ?? []).contains(where: { $0 === pos }) }) {
            return co.name
        }
        return ""
    }
}

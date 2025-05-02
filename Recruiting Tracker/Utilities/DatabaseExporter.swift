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
    
    static func exportToCSV(candidates: [Candidate]) -> String {
        var csv = "Name,Phone,Email,Lead Source,Years Experience,Technician Level,Hiring Status,Hot Candidate,Needs Follow Up,Needs Insurance,Date Entered\n"
        
        for candidate in candidates {
            csv += "\"\(candidate.name)\","
            csv += "\"\(candidate.phoneNumber)\","
            csv += "\"\(candidate.email)\","
            csv += "\"\(candidate.leadSource.rawValue)\","
            csv += "\(candidate.yearsOfExperience),"
            csv += "\"\(candidate.technicianLevel.rawValue)\","
            csv += "\"\(candidate.hiringStatus.rawValue)\","
            csv += "\(candidate.isHotCandidate),"
            csv += "\(candidate.needsFollowUp),"
            csv += "\(candidate.needsHealthInsurance),"
            csv += "\"\(candidate.dateEntered.formatted())\"\n"
        }
        
        return csv
    }
}

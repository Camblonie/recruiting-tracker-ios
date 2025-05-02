import Foundation
import SwiftData

// MARK: - Enums
enum LeadSource: String, Codable, CaseIterable {
    case indeed = "Indeed"
    case careerBuilder = "Career Builder"
    case zipRecruiter = "ZIP Recruiter"
    case inPerson = "In-Person"
    case monster = "Monster"
    case referral = "Referral"
}

enum PreviousEmployer: String, Codable, CaseIterable {
    case dealership = "Dealership"
    case independent = "Independent"
    case belle = "Belle"
    case discount = "Discount"
    case other = "Other"
}

enum TechnicalFocus: String, Codable, CaseIterable {
    case electrical = "Electrical"
    case driveability = "Drive-ability"
    case maintenance = "Maintenance"
    case lof = "LOF"
    case lightMechanical = "Light Mechanical"
    case brakes = "Brakes"
}

enum TechnicianLevel: String, Codable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case lubeTech = "Lube Tech"
}

enum HiringStatus: String, Codable, CaseIterable {
    case notContacted = "Not Contacted"
    case ghosted = "Ghosted Replies"
    case visitForInterview = "Visit for Interview"
    case noShow = "No Show for Interview"
    case offer = "Offer"
    case hired = "Hired"
    case rejectedOffer = "Rejected Offer"
    case futureOffer = "Intention to Offer"
}

// MARK: - Supporting Types
struct AvoidFlagEntry: Codable {
    let date: Date
    let isEnabled: Bool
    let reason: String?
}

// MARK: - Candidate Model
@Model
final class Candidate {
    // MARK: - Properties
    var id: String
    
    // Basic Information
    var name: String
    var phoneNumber: String
    var email: String
    var leadSource: LeadSource
    var referralName: String?
    
    // Experience and Skills
    var yearsOfExperience: Int
    var previousEmployers: [PreviousEmployer]
    var technicalFocus: [TechnicalFocus]
    var technicianLevel: TechnicianLevel
    
    // Status and Flags
    var hiringStatus: HiringStatus
    var needsFollowUp: Bool
    var isHotCandidate: Bool
    private(set) var avoidCandidate: Bool
    var avoidFlagHistory: [AvoidFlagEntry]
    
    // Compensation
    var conceptPayScale: String?
    var conceptPayDate: Date?
    var needsHealthInsurance: Bool
    
    // Additional Information
    var offerDetail: String?
    var offerDate: Date?
    var picture: Data?
    var socialMediaLinks: [String]
    var notes: String
    var dateEntered: Date
    
    // Relationships
    @Relationship var attachedFiles: [CandidateFile]
    
    // MARK: - Initialization
    init(name: String,
         phoneNumber: String,
         email: String,
         leadSource: LeadSource,
         referralName: String? = nil,
         yearsOfExperience: Int,
         previousEmployers: [PreviousEmployer],
         technicalFocus: [TechnicalFocus],
         technicianLevel: TechnicianLevel,
         hiringStatus: HiringStatus = .notContacted,
         dateEntered: Date = Date()) {
        
        self.id = UUID().uuidString
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.leadSource = leadSource
        self.referralName = referralName
        self.yearsOfExperience = yearsOfExperience
        self.previousEmployers = previousEmployers
        self.technicalFocus = technicalFocus
        self.technicianLevel = technicianLevel
        self.hiringStatus = hiringStatus
        
        // Initialize flags
        self.needsFollowUp = false
        self.isHotCandidate = false
        self.avoidCandidate = false
        self.avoidFlagHistory = []
        
        // Initialize other properties
        self.needsHealthInsurance = false
        self.socialMediaLinks = []
        self.notes = ""
        self.dateEntered = dateEntered
        self.attachedFiles = []
    }
    
    // MARK: - Flag Management
    func updateAvoidFlag(to newValue: Bool, reason: String? = nil) {
        // Only record history if the value is changing
        if newValue != avoidCandidate {
            let entry = AvoidFlagEntry(
                date: Date(),
                isEnabled: newValue,
                reason: reason
            )
            avoidFlagHistory.append(entry)
            avoidCandidate = newValue
        }
    }
    
    // MARK: - Data Export
    func exportData() -> String {
        var export = """
        Candidate Profile
        ================
        Basic Information:
        Name: \(name)
        Phone: \(phoneNumber)
        Email: \(email)
        Lead Source: \(leadSource.rawValue)
        \(referralName != nil ? "Referred By: \(referralName!)" : "")
        
        Experience:
        Years of Experience: \(yearsOfExperience)
        Technician Level: \(technicianLevel.rawValue)
        Previous Employers: \(previousEmployers.map { $0.rawValue }.joined(separator: ", "))
        Technical Focus: \(technicalFocus.map { $0.rawValue }.joined(separator: ", "))
        
        Status:
        Hiring Status: \(hiringStatus.rawValue)
        Follow Up Required: \(needsFollowUp ? "Yes" : "No")
        Hot Candidate: \(isHotCandidate ? "Yes" : "No")
        Avoid Flag: \(avoidCandidate ? "Yes" : "No")
        
        """
        
        if !avoidFlagHistory.isEmpty {
            export += "\nAvoid Flag History:\n"
            for entry in avoidFlagHistory {
                export += "- \(entry.date.formatted()): \(entry.isEnabled ? "Enabled" : "Disabled")"
                if let reason = entry.reason {
                    export += " (Reason: \(reason))"
                }
                export += "\n"
            }
        }
        
        export += """
        
        Compensation:
        \(conceptPayScale != nil ? "Concept Pay Scale: \(conceptPayScale!)" : "")
        \(conceptPayDate != nil ? "Pay Scale Date: \(conceptPayDate!.formatted())" : "")
        Needs Health Insurance: \(needsHealthInsurance ? "Yes" : "No")
        
        Additional Information:
        \(offerDetail != nil ? "Offer Details: \(offerDetail!)" : "")
        \(offerDate != nil ? "Offer Date: \(offerDate!.formatted())" : "")
        Social Media: \(socialMediaLinks.joined(separator: ", "))
        
        Notes:
        \(notes)
        
        Date Entered: \(dateEntered.formatted())
        
        Attached Files:
        \(attachedFiles.map { $0.fileName }.joined(separator: ", "))
        """
        
        return export
    }
}

// MARK: - Identifiable
extension Candidate: Identifiable {}

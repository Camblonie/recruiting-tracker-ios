import Foundation
import SwiftData

enum ValidationError: LocalizedError {
    case invalidEmail
    case invalidPhoneNumber
    case duplicateCandidate
    case missingRequiredField(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Invalid email address"
        case .invalidPhoneNumber:
            return "Invalid phone number format"
        case .duplicateCandidate:
            return "A candidate with this information already exists"
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        }
    }
}

struct CandidateValidator {
    static func validate(_ candidate: Candidate) throws {
        // Name is no longer required, allowing blank values
        
        // Validate email only if not empty
        if !candidate.email.isEmpty && !validateEmail(candidate.email) {
            throw ValidationError.invalidEmail
        }
        
        // Validate phone number only if not empty
        if !candidate.phoneNumber.isEmpty && !validatePhoneNumber(candidate.phoneNumber) {
            throw ValidationError.invalidPhoneNumber
        }
    }
    
    static func checkForDuplicates(candidate: Candidate, in context: ModelContext) throws {
        let isDuplicate = try isDuplicate(name: candidate.name, phoneNumber: candidate.phoneNumber, context: context)
        if isDuplicate {
            throw ValidationError.duplicateCandidate
        }
    }
    
    static func isDuplicate(name: String, phoneNumber: String, context: ModelContext) throws -> Bool {
        // Don't use complex predicates that SwiftData can't handle
        // Instead, fetch by phone number only, which is simpler
        if !phoneNumber.isEmpty {
            let descriptor = FetchDescriptor<Candidate>(
                predicate: #Predicate<Candidate> { $0.phoneNumber == phoneNumber }
            )
            let matches = try context.fetch(descriptor)
            if !matches.isEmpty {
                return true
            }
        }
        
        // Then manually check for name matches
        if !name.isEmpty {
            // Get all candidates and filter in memory
            let allCandidates = try context.fetch(FetchDescriptor<Candidate>())
            for candidate in allCandidates {
                if candidate.name.lowercased() == name.lowercased() {
                    return true
                }
            }
        }
        
        return false
    }
    
    static func validatePhoneNumber(_ number: String) -> Bool {
        // Remove all non-numeric characters
        let digits = number.filter { $0.isNumber }
        
        // Check if we have 10 digits (US phone number)
        return digits.count == 10
    }
    
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

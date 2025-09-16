import XCTest
import SwiftData
@testable import Recruiting_Tracker

@MainActor
final class CandidateValidatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    
    override func setUpWithError() throws {
        let schema = Schema([Candidate.self, Company.self, Position.self, CandidateFile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }
    
    override func tearDownWithError() throws {
        container = nil
    }
    
    func testValidate_AllowsEmptyEmailAndPhone() throws {
        // Given
        let candidate = Candidate(
            name: "",
            phoneNumber: "",
            email: "",
            leadSource: .referral,
            yearsOfExperience: 0,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        
        // Then (no throw)
        XCTAssertNoThrow(try CandidateValidator.validate(candidate))
    }
    
    func testValidate_InvalidEmailThrows() throws {
        // Given
        let candidate = Candidate(
            name: "Jane Doe",
            phoneNumber: "",
            email: "jane@",
            leadSource: .referral,
            yearsOfExperience: 0,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        
        // Then
        XCTAssertThrowsError(try CandidateValidator.validate(candidate)) { error in
            guard case ValidationError.invalidEmail = error else {
                return XCTFail("Expected invalidEmail, got: \(error)")
            }
        }
    }
    
    func testValidate_InvalidPhoneThrows() throws {
        // Given
        let candidate = Candidate(
            name: "Jane Doe",
            phoneNumber: "123-45",
            email: "",
            leadSource: .referral,
            yearsOfExperience: 0,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        
        // Then
        XCTAssertThrowsError(try CandidateValidator.validate(candidate)) { error in
            guard case ValidationError.invalidPhoneNumber = error else {
                return XCTFail("Expected invalidPhoneNumber, got: \(error)")
            }
        }
    }
    
    func testDuplicateDetection_ByPhone() throws {
        // Insert an existing candidate
        let existing = Candidate(
            name: "John Smith",
            phoneNumber: "5551234567",
            email: "",
            leadSource: .referral,
            yearsOfExperience: 1,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        context.insert(existing)
        try context.save()
        
        // When checking duplicate by same phone
        let isDup = try CandidateValidator.isDuplicate(
            name: "",
            phoneNumber: "5551234567",
            context: context
        )
        
        // Then
        XCTAssertTrue(isDup)
    }
}

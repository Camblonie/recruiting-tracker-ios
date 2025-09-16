import XCTest
import SwiftData
@testable import Recruiting_Tracker

@MainActor
final class SearchFilterTests: XCTestCase {
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
    
    private func makeCandidate(
        name: String,
        email: String,
        phone: String,
        leadSource: LeadSource,
        years: Int,
        dateEntered: Date
    ) -> Candidate {
        let c = Candidate(
            name: name,
            phoneNumber: phone,
            email: email,
            leadSource: leadSource,
            yearsOfExperience: years,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown,
            dateEntered: dateEntered
        )
        return c
    }
    
    func testTextSearchFiltersResults() throws {
        // Given
        let a = makeCandidate(name: "Termy Alina", email: "alina@example.com", phone: "1112223333", leadSource: .indeed, years: 1, dateEntered: .distantPast)
        let b = makeCandidate(name: "Bob Jones", email: "bob@example.com", phone: "4445556666", leadSource: .indeed, years: 2, dateEntered: .distantPast)
        context.insert(a)
        context.insert(b)
        try context.save()
        
        // When
        let filter = SearchFilter(name: "Text")
        filter.searchText = "Termy"
        let results = try filter.getFilteredCandidates(from: context)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Termy Alina")
    }
    
    func testLeadSourceFilter() throws {
        // Given
        let a = makeCandidate(name: "Alice", email: "a@example.com", phone: "1111111111", leadSource: .indeed, years: 1, dateEntered: .distantPast)
        let b = makeCandidate(name: "Bob", email: "b@example.com", phone: "2222222222", leadSource: .referral, years: 1, dateEntered: .distantPast)
        context.insert(a)
        context.insert(b)
        try context.save()
        
        // When
        let filter = SearchFilter(name: "LeadSource")
        filter.leadSources = [.referral]
        let results = try filter.getFilteredCandidates(from: context)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.leadSource, .referral)
        XCTAssertEqual(results.first?.name, "Bob")
    }
    
    func testDateRangeFilter() throws {
        // Given
        let d1 = Date(timeIntervalSince1970: 1_700_000_000)
        let d2 = Date(timeIntervalSince1970: 1_700_100_000)
        let early = makeCandidate(name: "Early", email: "e@example.com", phone: "1111111111", leadSource: .indeed, years: 1, dateEntered: d1)
        let later = makeCandidate(name: "Later", email: "l@example.com", phone: "2222222222", leadSource: .indeed, years: 1, dateEntered: d2)
        context.insert(early)
        context.insert(later)
        try context.save()
        
        // When
        let filter = SearchFilter(name: "Range")
        filter.dateRange = d1...d1
        let results = try filter.getFilteredCandidates(from: context)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Early")
    }
}

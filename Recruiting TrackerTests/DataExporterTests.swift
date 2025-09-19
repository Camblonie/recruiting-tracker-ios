import XCTest
import SwiftData
@testable import Recruiting_Tracker

@MainActor
final class DataExporterTests: XCTestCase {
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
    
    func testCSVExport_ContainsHeadersAndRows() throws {
        // Given: two candidates in the store
        let c1 = Candidate(
            name: "Alice Smith",
            phoneNumber: "1112223333",
            email: "alice@example.com",
            leadSource: .indeed,
            yearsOfExperience: 3,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown,
            dateEntered: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let c2 = Candidate(
            name: "Bob Jones",
            phoneNumber: "4445556666",
            email: "bob@example.com",
            leadSource: .zipRecruiter,
            yearsOfExperience: 5,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown,
            dateEntered: Date(timeIntervalSince1970: 1_700_100_000)
        )
        context.insert(c1)
        context.insert(c2)
        try context.save()
        
        // When: exporting CSV with default headers (now includes First/Last Name)
        let exporter = DataExporter(modelContext: context)
        let config = ExportConfiguration(format: .csv, includeFields: [], dateRange: nil, filter: nil, sortOption: nil)
        let data = try exporter.exportData(config: config)
        let csv = String(data: data, encoding: .utf8) ?? ""
        
        // Then: header row and both names present split across first/last
        XCTAssertTrue(csv.hasPrefix("First Name,Last Name,Email,Phone,Lead Source"), "CSV should start with updated default headers")
        XCTAssertTrue(csv.contains("Alice"))
        XCTAssertTrue(csv.contains("Smith"))
        XCTAssertTrue(csv.contains("Bob"))
        XCTAssertTrue(csv.contains("Jones"))
        XCTAssertTrue(csv.contains("1112223333"))
        XCTAssertTrue(csv.contains("4445556666"))
    }
    
    func testJSONExport_HasExpectedKeysAndValues() throws {
        // Given: single candidate
        let c = Candidate(
            name: "Charlie Test",
            phoneNumber: "9998887777",
            email: "charlie@example.com",
            leadSource: .referral,
            yearsOfExperience: 2,
            previousEmployers: [.independent],
            technicalFocus: [.maintenance],
            technicianLevel: .unknown,
            dateEntered: Date(timeIntervalSince1970: 1_700_200_000)
        )
        context.insert(c)
        try context.save()
        
        // When: exporting JSON
        let exporter = DataExporter(modelContext: context)
        let config = ExportConfiguration(format: .json, includeFields: [], dateRange: nil, filter: nil, sortOption: nil)
        let data = try exporter.exportData(config: config)
        
        // Then: decode JSON and validate keys (updated defaults use split name fields)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = obj as? [[String: Any]] else {
            return XCTFail("Expected array of dictionaries")
        }
        // Find candidate row by split name
        let row = arr.first { ($0["First Name"] as? String) == "Charlie" && ($0["Last Name"] as? String)?.contains("Test") == true }
        XCTAssertNotNil(row)
        XCTAssertEqual(row?["Email"] as? String, "charlie@example.com")
        XCTAssertEqual(row?["Phone"] as? String, "9998887777")
        XCTAssertEqual(row?["Lead Source"] as? String, LeadSource.referral.rawValue)
    }
}

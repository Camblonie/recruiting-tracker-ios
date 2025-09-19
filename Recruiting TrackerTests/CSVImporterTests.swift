import XCTest
import SwiftData
@testable import Recruiting_Tracker

@MainActor
final class CSVImporterTests: XCTestCase {
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

    func testImportCandidates_FromValidCSV_ImportsTwo() throws {
        // Given: CSV matching DatabaseExporter format
        let header = "Name,Phone,Email,Lead Source,Years Experience,Technician Level,Hiring Status,Hot Candidate,Needs Follow Up,Needs Insurance,Date Entered\n"
        let row1 = "\"Alice Smith\",1112223333,alice@example.com,Indeed,3,Unknown,Not Contacted,true,false,false,1/1/2024\n"
        let row2 = "\"Bob Jones\",4445556666,bob@example.com,ZIP Recruiter,5,Unknown,Hired,false,true,true,2/2/2024\n"
        let csv = header + row1 + row2
        let data = Data(csv.utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertTrue(result.errors.isEmpty)

        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched.contains(where: { $0.name == "Alice Smith" }))
        XCTAssertTrue(fetched.contains(where: { $0.name == "Bob Jones" }))
    }

    func testImportCandidates_DeduplicatesByNameAndPhone() throws {
        // Given: One candidate already exists
        let existing = Candidate(
            name: "Alice Smith",
            phoneNumber: "1112223333",
            email: "already@here.com",
            leadSource: .indeed,
            yearsOfExperience: 1,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        context.insert(existing)
        try context.save()

        let header = "Name,Phone,Email,Lead Source,Years Experience,Technician Level,Hiring Status,Hot Candidate,Needs Follow Up,Needs Insurance,Date Entered\n"
        let dupRow = "\"Alice Smith\",1112223333,alice@example.com,Indeed,3,Unknown,Not Contacted,true,false,false,1/1/2024\n"
        let newRow = "\"Charlie Test\",9998887777,charlie@example.com,Referral,2,Unknown,Offer,false,false,false,1/10/2024\n"
        let data = Data((header + dupRow + newRow).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then: Only one new candidate should be imported
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched.contains(where: { $0.name == "Charlie Test" }))
    }
}

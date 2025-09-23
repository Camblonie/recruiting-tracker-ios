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

    func testImportCandidates_FirstLastName_ComposesFullName() throws {
        // Given: First/Last Name columns only (no legacy Name)
        let header = "First Name,Last Name,Phone,Email,Lead Source,Skill Level\n"
        let row = "Alice,Smith,1112223333,alice@example.com,Indeed,A\n"
        let data = Data((header + row).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 1)
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Alice Smith")
    }

    func testImportCandidates_MalformedQuotes_FallbackParses() throws {
        // Given: Unclosed quote in the row should trigger ignoreQuotes fallback
        let header = "Name,Phone,Email,Lead Source\n"
        let badRow = "\"Alice Smith,1112223333,alice@example.com,Indeed\n" // opening quote never closes
        let data = Data((header + badRow).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 1)
        // Do not require no errors; importer may add diagnostics depending on parse shape
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertTrue(fetched.first?.name.contains("Alice Smith") == true)
    }

    func testImportCandidates_SemicolonDelimiter_Autodetected() throws {
        // Given: Excel-style delimiter directive with semicolons
        let header = "sep=;\nName;Phone;Email;Lead Source\n"
        let row = "Bob Jones;4445556666;bob@example.com;ZIP Recruiter\n"
        let data = Data((header + row).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 1)
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertTrue(fetched.contains(where: { $0.name == "Bob Jones" }))
    }

    func testImportCandidates_MissingName_SkipsWithError() throws {
        // Given: No name columns present
        let header = "Phone,Email,Lead Source\n"
        let row = "1234567890,noname@example.com,Indeed\n"
        let data = Data((header + row).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("Missing required Name") }))
    }

    func testImportCandidates_CompanyAssociation_CreatesDefaultPosition() throws {
        // Given: Company column should associate candidate to a default "General" position
        let header = "Name,Phone,Email,Lead Source,Company\n"
        let row = "\"Charlie Example\",9990001111,charlie@example.com,Referral,ACME Corp\n"
        let data = Data((header + row).utf8)

        // When
        _ = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        let candidates = try context.fetch(FetchDescriptor<Candidate>())
        let companies = try context.fetch(FetchDescriptor<Company>())
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(companies.count, 1)
        let candidate = try XCTUnwrap(candidates.first)
        let position = try XCTUnwrap(candidate.position)
        XCTAssertEqual(position.title, "General")
        XCTAssertEqual(position.company?.name, "ACME Corp")
    }

    func testImportCandidates_ContactedColumn_AdjustsHiringStatus() throws {
        // Given: Contacted true should bump status from Not Contacted
        let header = "Name,Phone,Lead Source,Contacted\n"
        let row = "\"Dana Test\",2223334444,Indeed,true\n"
        let data = Data((header + row).utf8)

        // When
        _ = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        let dana = try context.fetch(FetchDescriptor<Candidate>()).first(where: { $0.name == "Dana Test" })
        XCTAssertEqual(dana?.hiringStatus, .visitForInterview)

        // And: Contacted false should explicitly set Not Contacted
        let header2 = "Name,Phone,Lead Source,Contacted\n"
        let row2 = "\"Evan Test\",5556667777,Indeed,false\n"
        let data2 = Data((header2 + row2).utf8)
        _ = CSVImporter.importCandidates(csvData: data2, into: context)
        let evan = try context.fetch(FetchDescriptor<Candidate>()).first(where: { $0.name == "Evan Test" })
        XCTAssertEqual(evan?.hiringStatus, .notContacted)
    }

    func testImportCandidates_DateParsing_VariousFormats() throws {
        // Given: Different date formats accepted by importer
        let header = "Name,Phone,Email,Lead Source,Date Entered\n"
        let row1 = "\"Fiona Date\",1010101010,fiona@example.com,Indeed,1/2/2024\n"
        let data = Data((header + row1).utf8)

        // When
        _ = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        let fiona = try context.fetch(FetchDescriptor<Candidate>()).first(where: { $0.name == "Fiona Date" })
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: try XCTUnwrap(fiona?.dateEntered))
        XCTAssertEqual(comps.year, 2024)
        XCTAssertEqual(comps.month, 1)
        XCTAssertEqual(comps.day, 2)
    }

    func testImportCandidates_Dedup_IgnoresCaseAndPhoneWhitespace() throws {
        // Given: existing candidate in lowercase name and compact phone
        let existing = Candidate(
            name: "alice smith",
            phoneNumber: "1112223333",
            email: "a@b.com",
            leadSource: .indeed,
            yearsOfExperience: 0,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        context.insert(existing)
        try context.save()

        // Row with different case and spaced phone should be detected as duplicate
        let header = "Name,Phone,Lead Source\n"
        let dupRow = "Alice Smith,111 222 3333,Indeed\n"
        let data = Data((header + dupRow).utf8)

        // When
        let result = CSVImporter.importCandidates(csvData: data, into: context)

        // Then
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertEqual(fetched.count, 1)
    }
}

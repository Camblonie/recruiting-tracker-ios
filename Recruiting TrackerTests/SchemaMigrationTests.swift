import XCTest
import SwiftData
@testable import Recruiting_Tracker

// Tests for schema versioning scaffolding and migration manager behavior.
@MainActor
final class SchemaMigrationTests: XCTestCase {
    func testVersionedSchemaModelsV1IncludesCoreModels() {
        // Ensure AppSchemaV1 exposes all core models to SwiftData
        let modelNames = AppSchemaV1.models.map { String(describing: $0) }
        XCTAssertTrue(modelNames.contains("Candidate"))
        XCTAssertTrue(modelNames.contains("Company"))
        XCTAssertTrue(modelNames.contains("Position"))
        XCTAssertTrue(modelNames.contains("CandidateFile"))
    }

    func testMigrationPlanHasNoStagesYet() {
        // As of now we expect no custom migration stages
        XCTAssertTrue(AppMigrationPlan.stages.isEmpty)
    }

    func testConfigureModelConfiguration_AllowsContainerCreation() throws {
        // Given: migration manager-provided configuration
        let config = MigrationManager.configureModelConfiguration()
        // When: creating a container explicitly using schema
        let schema = Schema([Candidate.self, Company.self, Position.self, CandidateFile.self])
        let container = try ModelContainer(for: schema, configurations: config)
        // Then: basic write/read succeeds
        let context = container.mainContext
        let alice = Candidate(
            name: "Schema Test",
            phoneNumber: "000",
            email: "schema@test.dev",
            leadSource: .indeed,
            yearsOfExperience: 0,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        context.insert(alice)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertTrue(fetched.contains(where: { $0.name == "Schema Test" }))
    }

    func testMigrationManagerCreateContainer_SaveAndFetch() throws {
        // When: using MigrationManager factory
        let container = try MigrationManager.createContainer()
        let context = container.mainContext

        // Then: we can write and read a record
        let bob = Candidate(
            name: "Manager Test",
            phoneNumber: "111",
            email: "manager@test.dev",
            leadSource: .indeed,
            yearsOfExperience: 1,
            previousEmployers: [],
            technicalFocus: [],
            technicianLevel: .unknown
        )
        context.insert(bob)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Candidate>())
        XCTAssertTrue(fetched.contains(where: { $0.name == "Manager Test" }))
    }
}

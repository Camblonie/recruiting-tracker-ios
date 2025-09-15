import Foundation
import SwiftData
import CloudKit

// MARK: - Schema Migration Plan

/**
 * This file contains the schema migration plan for the app's data models.
 * It defines how to migrate data between different schema versions.
 * Also configures CloudKit sync for cross-device data sharing.
 */

// MARK: - Versioned Schemas

/// Baseline schema for v1. Matches current production models.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            Candidate.self,
            Company.self,
            Position.self,
            CandidateFile.self
        ]
    }
}

// If/when we introduce breaking model changes, create AppSchemaV2 and add a
// migration stage (lightweight or custom) below. For now we establish v1.

// MARK: - Migration Plan
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        AppSchemaV1.self
    ]
    
    // No stages yet; future versions will add lightweight or custom stages here.
    static var stages: [MigrationStage] = []
}

// MARK: - Migration Helper
class MigrationManager {
    // Configure ModelConfiguration with CloudKit support and migration plan
    static func configureModelConfiguration() -> ModelConfiguration {
        let containerIdentifier = "iCloud.com.scottcampbell.Recruiting-Tracker"
        return ModelConfiguration(
            "RecruitingTrackerDB",
            schema: Schema([Candidate.self, Company.self, Position.self, CandidateFile.self]),
            migrationPlan: AppMigrationPlan.self,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }
    
    // Create a model container with migration support and CloudKit sync
    static func createContainer() throws -> ModelContainer {
        do {
            // First try creating with CloudKit configuration
            print("Creating ModelContainer with CloudKit configuration")
            let config = configureModelConfiguration()
            return try ModelContainer(for: Candidate.self, Company.self, Position.self, CandidateFile.self, configurations: config)
        } catch {
            print("Error creating CloudKit ModelContainer: \(error), trying alternative approach")
            
            // If that fails, try with basic configuration
            do {
                print("Creating ModelContainer with basic configuration")
                return try ModelContainer(for: Candidate.self, Company.self, Position.self, CandidateFile.self)
            } catch {
                print("Error creating basic ModelContainer: \(error), trying with explicit schema")
                
                // Last resort: try with explicit schema
                do {
                    let schema = Schema([Candidate.self, Company.self, Position.self, CandidateFile.self])
                    print("Creating ModelContainer with explicit schema")
                    return try ModelContainer(for: schema)
                } catch {
                    print("Error creating ModelContainer with explicit schema: \(error)")
                    throw error
                }
            }
        }
    }
}

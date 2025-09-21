//
//  Recruiting_TrackerApp.swift
//  Recruiting Tracker
//
//  Created by Scott Campbell on 5/1/25.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct Recruiting_TrackerApp: App {
    let modelContainer: ModelContainer
    @State private var isOnboarding = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("didMigrateLocalToCloud") private var didMigrateLocalToCloud = false
    @AppStorage("useCloudSync") private var useCloudSync = false
    
    init() {
        do {
            // Include all @Model types used in the app to avoid container init failures
            // CloudKit mirroring is automatically enabled when the iCloud capability and
            // the container (iCloud.com.camblonie.RecruitingTracker) are configured in
            // Signing & Capabilities and the app entitlements. No explicit parameter is required here.
            // Choose persistence based on Cloud Sync toggle. Default to local.
            let storedUseCloud = UserDefaults.standard.bool(forKey: "useCloudSync")
            if storedUseCloud {
                #if swift(>=5.10)
                if #available(iOS 18.0, *) {
                    print("[Startup] Cloud Sync ON: attempting CloudKit store")
                    let ckConfig = ModelConfiguration(
                        "RecruitingTrackerDB",
                        schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                        cloudKitDatabase: .private("iCloud.com.camblonie.RecruitingTracker")
                    )
                    do {
                        modelContainer = try ModelContainer(
                            for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                            configurations: ckConfig
                        )
                    } catch {
                        print("[Startup] CloudKit ModelContainer failed: \(error). Falling back to local store.")
                        let localConfig = ModelConfiguration(
                            "LocalRecruitingTrackerDB",
                            schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                            isStoredInMemoryOnly: false
                        )
                        modelContainer = try ModelContainer(
                            for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                            configurations: localConfig
                        )
                    }
                } else {
                    print("[Startup] Cloud Sync requires iOS 18+. Using local persistent store")
                    let localConfig = ModelConfiguration(
                        "LocalRecruitingTrackerDB",
                        schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                        isStoredInMemoryOnly: false
                    )
                    modelContainer = try ModelContainer(
                        for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                        configurations: localConfig
                    )
                }
                #else
                // Older toolchains: use local only
                let localConfig = ModelConfiguration(
                    "LocalRecruitingTrackerDB",
                    schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                    isStoredInMemoryOnly: false
                )
                modelContainer = try ModelContainer(
                    for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                    configurations: localConfig
                )
                #endif
            } else {
                print("[Startup] Cloud Sync OFF: using local persistent store")
                let localConfig = ModelConfiguration(
                    "LocalRecruitingTrackerDB",
                    schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                    isStoredInMemoryOnly: false
                )
                modelContainer = try ModelContainer(
                    for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                    configurations: localConfig
                )
            }
            // Migration disabled: CloudKit mirroring (via entitlements) should handle existing data automatically.
        } catch {
            // Graceful fallbacks to avoid crashing at launch
            print("Primary ModelContainer (CloudKit/local) failed: \(error)")
            // 1) Try a CloudKit/basic container via MigrationManager
            if let container = try? MigrationManager.createContainer() {
                print("[Fallback] Using MigrationManager container (CloudKit/basic)")
                modelContainer = container
                return
            }
            // 2) Try a default local persistent container
            if let persistent = try? ModelContainer(for: Company.self, Position.self, Candidate.self, CandidateFile.self) {
                print("[Fallback] Using default persistent ModelContainer")
                modelContainer = persistent
                return
            }
            // 3) Try an in-memory container as a last resort
            if let mem = try? ModelContainer(
                for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                configurations: ModelConfiguration(
                    schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                    isStoredInMemoryOnly: true
                )
            ) {
                print("[Fallback] Using in-memory ModelContainer; persistence disabled this session.")
                modelContainer = mem
                return
            }
            // 4) If absolutely everything fails, report but avoid force-crash by creating a minimal in-memory schema container
            let emptySchema = Schema([Company.self, Position.self, Candidate.self, CandidateFile.self])
            let memConfig = ModelConfiguration(schema: emptySchema, isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: Company.self, Position.self, Candidate.self, CandidateFile.self, configurations: memConfig)
            } catch {
                // If this fails too, we must abort; log detailed error
                fatalError("Unrecoverable: failed to create any ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isOnboarding {
                    OnboardingView(isOnboarding: $isOnboarding)
                } else {
                    MainTabView()
                }
            }
            .onAppear {
                // Check if we need to show onboarding
                let context = modelContainer.mainContext
                let descriptor = FetchDescriptor<Company>()
                if let companies = try? context.fetch(descriptor) {
                    // Show onboarding only if there are no companies AND onboarding hasn't been completed
                    isOnboarding = companies.isEmpty && !didCompleteOnboarding
                }
            }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Migration
    /// Copies data from the previous local SQLite store ("RecruitingTrackerDB") into the CloudKit-backed store.
    /// Runs only once and only when the CloudKit store is empty.
    private func migrateLocalStoreToCloudIfNeeded(cloudContainer: ModelContainer) {
        guard !didMigrateLocalToCloud else { return }
        let cloudContext = cloudContainer.mainContext
        // If Cloud already has data, consider migration done
        if let cloudCount = try? cloudContext.fetchCount(FetchDescriptor<Candidate>()), cloudCount > 0 {
            didMigrateLocalToCloud = true
            return
        }

        // Open the legacy local (on-device) store
        do {
            let localConfig = ModelConfiguration(
                "RecruitingTrackerDB",
                schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                isStoredInMemoryOnly: false
            )
            let localContainer = try ModelContainer(
                for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                configurations: localConfig
            )
            let localContext = localContainer.mainContext

            let localCompanies = try localContext.fetch(FetchDescriptor<Company>())
            let localCandidates = try localContext.fetch(FetchDescriptor<Candidate>())
            let localFiles = try localContext.fetch(FetchDescriptor<CandidateFile>())

            // Nothing to migrate
            if localCompanies.isEmpty && localCandidates.isEmpty {
                didMigrateLocalToCloud = true
                return
            }

            // Create mappings while inserting into Cloud context
            var companyMap: [ObjectIdentifier: Company] = [:]
            var positionMap: [ObjectIdentifier: Position] = [:]
            var candidateMap: [String: Candidate] = [:]

            // Companies and their positions
            for co in localCompanies {
                let newCo = Company(name: co.name, icon: co.icon)
                cloudContext.insert(newCo)
                companyMap[ObjectIdentifier(co)] = newCo
                for pos in (co.positions ?? []) {
                    let newPos = Position(title: pos.title, positionDescription: pos.positionDescription)
                    if newCo.positions == nil { newCo.positions = [] }
                    newCo.positions?.append(newPos)
                    positionMap[ObjectIdentifier(pos)] = newPos
                }
            }

            // Candidates
            for cand in localCandidates {
                let newCand = Candidate(
                    name: cand.name,
                    phoneNumber: cand.phoneNumber,
                    email: cand.email,
                    leadSource: cand.leadSource,
                    referralName: cand.referralName,
                    yearsOfExperience: cand.yearsOfExperience,
                    previousEmployers: cand.previousEmployers,
                    technicalFocus: cand.technicalFocus,
                    technicianLevel: cand.technicianLevel,
                    hiringStatus: cand.hiringStatus,
                    position: nil,
                    dateEntered: cand.dateEntered
                )
                // Copy flags & extra fields
                newCand.needsFollowUp = cand.needsFollowUp
                newCand.isHotCandidate = cand.isHotCandidate
                if cand.avoidCandidate { newCand.updateAvoidFlag(to: true, reason: "Migrated") }
                newCand.avoidFlagHistory = cand.avoidFlagHistory
                newCand.conceptPayScale = cand.conceptPayScale
                newCand.conceptPayDate = cand.conceptPayDate
                newCand.needsHealthInsurance = cand.needsHealthInsurance
                newCand.offerDetail = cand.offerDetail
                newCand.offerDate = cand.offerDate
                newCand.picture = cand.picture
                newCand.socialMediaLinks = cand.socialMediaLinks
                newCand.notes = cand.notes

                // Re-link position
                if let oldPos = cand.position, let newPos = positionMap[ObjectIdentifier(oldPos)] {
                    newCand.position = newPos
                    if newPos.candidates == nil { newPos.candidates = [] }
                    newPos.candidates?.append(newCand)
                }

                cloudContext.insert(newCand)
                candidateMap[cand.id] = newCand
            }

            // Candidate files
            for file in localFiles {
                let newFile = CandidateFile(
                    fileName: file.fileName,
                    fileData: file.fileData,
                    fileType: file.fileType,
                    candidate: nil
                )
                if let oldCand = file.candidate, let mapped = candidateMap[oldCand.id] {
                    newFile.candidate = mapped
                }
                cloudContext.insert(newFile)
            }

            try cloudContext.save()
            didMigrateLocalToCloud = true
        } catch {
            // If migration fails, we skip to allow app use with empty Cloud store
            print("Migration warning: \(error)")
        }
    }
}

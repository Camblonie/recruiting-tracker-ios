//
//  Recruiting_TrackerApp.swift
//  Recruiting Tracker
//
//  Created by Scott Campbell on 5/1/25.
//

import SwiftUI
import SwiftData

@main
struct Recruiting_TrackerApp: App {
    let modelContainer: ModelContainer
    @State private var isOnboarding = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    
    init() {
        do {
            // Include all @Model types used in the app to avoid container init failures
            // Use a named, on-device persistent SQLite store
            let config = ModelConfiguration(
                "RecruitingTrackerDB",
                schema: Schema([Company.self, Position.self, Candidate.self, CandidateFile.self]),
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                configurations: config
            )
        } catch {
            // Graceful fallbacks to avoid crashing at launch
            if let container = try? MigrationManager.createContainer() {
                print("Warning: Primary ModelContainer init failed; using MigrationManager container. Error: \(error)")
                modelContainer = container
            } else {
                // Last resort: basic persistent container (on-device store)
                do {
                    modelContainer = try ModelContainer(for: Company.self, Position.self, Candidate.self, CandidateFile.self)
                } catch {
                    fatalError("Failed to create any persistent ModelContainer: \(error)")
                }
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
}

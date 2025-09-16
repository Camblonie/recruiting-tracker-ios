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
    
    init() {
        do {
            // Include all @Model types used in the app to avoid container init failures
            modelContainer = try ModelContainer(
                for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            // Graceful fallbacks to avoid crashing at launch
            if let container = try? MigrationManager.createContainer() {
                print("Warning: Primary ModelContainer init failed; using MigrationManager container. Error: \(error)")
                modelContainer = container
            } else if let memoryContainer = try? ModelContainer(
                for: Company.self, Position.self, Candidate.self, CandidateFile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ) {
                print("Warning: Using in-memory ModelContainer due to initialization errors. Error: \(error)")
                modelContainer = memoryContainer
            } else {
                // Last resort: explicit schema, in-memory
                let schema = Schema([Company.self, Position.self, Candidate.self, CandidateFile.self])
                do {
                    modelContainer = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                } catch {
                    fatalError("Failed to create any ModelContainer: \(error)")
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
                if let companies = try? context.fetch(descriptor),
                   companies.isEmpty {
                    isOnboarding = true
                }
            }
        }
        .modelContainer(modelContainer)
    }
}

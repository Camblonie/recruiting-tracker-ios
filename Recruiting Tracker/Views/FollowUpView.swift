import SwiftUI
import SwiftData
import UIKit

struct FollowUpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Candidate> { $0.needsFollowUp },
        sort: [SortDescriptor(\.dateEntered, order: .reverse)]
    ) private var candidates: [Candidate]
    // Force a lightweight refresh when a follow-up candidate is added from the add sheet
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.skyBlue.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(candidates) { candidate in
                            NavigationLink(destination: CandidateDetailView(candidate: candidate)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(candidate.name)
                                            .font(.headline)
                                            .foregroundColor(Color.slate)
                                        
                                        Spacer()
                                        
                                        Label("Follow Up", systemImage: "bell.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)
                                        
                                        HStack(spacing: 4) {
                                            Text(levelIndicator(for: candidate.technicianLevel))
                                                .font(.caption.bold())
                                                .padding(4)
                                                .background(levelGradient(for: candidate.technicianLevel))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    // Show split name lines for clarity (keeps combined name above for test compatibility)
                                    let parts = splitName(candidate.name)
                                    HStack(spacing: 6) {
                                        Text("First: \(parts.first)")
                                        if !parts.last.isEmpty {
                                            Text("Last: \(parts.last)")
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    
                                    Text(candidate.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Label("\(candidate.yearsOfExperience) years", systemImage: "clock")
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(candidate.hiringStatus.rawValue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.slate.opacity(0.1))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(4)
                                    }
                                    .font(.caption)
                                }
                                .padding(12)
                                .background(
                                    Color.cream.opacity(0.7)
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.slate.opacity(0.15), radius: 4, x: 0, y: 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            // Expose the candidate name as the cell's accessibility label for reliable UI testing
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(candidate.name)
                            .accessibilityIdentifier(candidate.name)
                        }
                    }
                }
                .listStyle(.plain)
                // Tie the content identity to refreshID so a change re-evaluates the view tree
                .id(refreshID)
                
                // Empty state overlay
                if candidates.isEmpty {
                    ContentUnavailableView {
                        Label("No Follow-Up Candidates", systemImage: "bell")
                            .foregroundColor(.blue)
                    } description: {
                        Text("Mark candidates as needing 'follow up' to see them here.")
                            .foregroundColor(.slate)
                    }
                    .background(Color.skyBlue.opacity(0.05))
                }
            }
            .navigationTitle("Follow Up")
            .toolbarBackground(Color.headerGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // Ensure navigation title is always white
            .onAppear {
                // Ensure navigation bar title text is white
                let navBarAppearance = UINavigationBar.appearance()
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                #if DEBUG
                let names = candidates.map { $0.name }.joined(separator: ", ")
                print("[FollowUp] count=\(candidates.count) names=[\(names)]")
                #endif
            }
            // Listen for newly added follow-up candidates and trigger a lightweight refresh
            .onReceive(NotificationCenter.default.publisher(for: .didAddFollowUpCandidate)) { _ in
                #if DEBUG
                print("[FollowUp] received didAddFollowUpCandidate -> refreshing view")
                #endif
                refreshID = UUID()
            }
        }
    }
    
    // Helper methods for displaying technician level with gradient colors
    private func levelGradient(for level: TechnicianLevel) -> LinearGradient {
        switch level {
        case .unknown:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "808080"), Color(hex: "A9A9A9")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .a:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "2E8B57"), Color(hex: "3CB371")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .b:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4F6D7A"), Color(hex: "6D8B9C")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .c:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "DD6E42"), Color(hex: "E58E65")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .lubeTech:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "8A2BE2"), Color(hex: "9370DB")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .salesAssoc:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "00BFA6"), Color(hex: "26D09E")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .manager:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "DAA520"), Color(hex: "FFD700")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func levelIndicator(for level: TechnicianLevel) -> String {
        switch level {
        case .unknown:
            return "N/A"
        case .a:
            return "A"
        case .b:
            return "B"
        case .c:
            return "C"
        case .lubeTech:
            return "LT"
        case .salesAssoc:
            return "SA"
        case .manager:
            return "M"
        }
    }

    // Split helper used for display only; model remains a single name field
    private func splitName(_ full: String) -> (first: String, last: String) {
        let comps = full.split(whereSeparator: { $0.isWhitespace })
        guard let first = comps.first else { return (full, "") }
        if comps.count == 1 { return (String(first), "") }
        let last = comps.dropFirst().joined(separator: " ")
        return (String(first), last)
    }
}

#Preview {
    FollowUpView()
}

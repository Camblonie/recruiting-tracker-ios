import SwiftUI
import SwiftData

struct HotCandidatesView: View {
    @Query(filter: #Predicate<Candidate> { candidate in
        candidate.isHotCandidate
    }) private var hotCandidates: [Candidate]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(hotCandidates) { candidate in
                    HotCandidateRow(candidate: candidate)
                }
            }
            .navigationTitle("Hot Candidates")
            .overlay {
                if hotCandidates.isEmpty {
                    ContentUnavailableView(
                        "No Hot Candidates",
                        systemImage: "flame",
                        description: Text("Candidates marked as hot will appear here")
                    )
                }
            }
        }
    }
}

struct HotCandidateRow: View {
    let candidate: Candidate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(candidate.name)
                .font(.headline)
            
            HStack {
                Label(candidate.technicianLevel.rawValue, systemImage: "wrench.and.screwdriver")
                Spacer()
                Label("\(candidate.yearsOfExperience) years", systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HotCandidatesView()
}

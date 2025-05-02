import SwiftUI
import SwiftData

struct HotCandidatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var candidates: [Candidate]
    
    init() {
        let predicate = #Predicate<Candidate> { candidate in
            candidate.isHotCandidate
        }
        let sortDescriptor = SortDescriptor(\Candidate.dateEntered, order: .reverse)
        _candidates = Query(filter: predicate, sort: [sortDescriptor])
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.skyBlue.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(candidates) { candidate in
                            NavigationLink(destination: CandidateDetailView(candidate: candidate)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(candidate.name)
                                            .font(.headline)
                                            .foregroundColor(Color.white)
                                        
                                        Spacer()
                                        
                                        HStack {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.cream)
                                                .font(.caption)
                                            
                                            Text(candidate.technicianLevel.rawValue)
                                                .font(.caption)
                                                .padding(4)
                                                .background(levelGradient(for: candidate.technicianLevel))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Text(candidate.email)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    HStack {
                                        Label("\(candidate.yearsOfExperience) years", systemImage: "clock")
                                            .foregroundColor(.cream.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Text(candidate.hiringStatus.rawValue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                    .font(.caption)
                                }
                                .padding(16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.terracotta, Color.terracotta.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.terracotta.opacity(0.4), radius: 5, x: 0, y: 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                
                // Empty state overlay
                if candidates.isEmpty {
                    ContentUnavailableView {
                        Label("No Hot Candidates", systemImage: "flame")
                            .foregroundColor(.terracotta)
                    } description: {
                        Text("Mark candidates as 'hot' to see them here.")
                            .foregroundColor(.slate)
                    }
                    .background(Color.skyBlue.opacity(0.05))
                }
            }
            .navigationTitle("Hot Candidates")
            .toolbarBackground(Color.headerGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
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
        }
    }
}

#Preview {
    HotCandidatesView()
}

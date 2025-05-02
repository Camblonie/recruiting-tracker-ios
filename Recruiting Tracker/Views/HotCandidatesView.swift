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
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(candidate.name)
                                            .font(.headline)
                                            .foregroundColor(Color.slate)
                                        
                                        Spacer()
                                        
                                        Label("Hot", systemImage: "flame.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.terracotta)
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
        }
    }
}

#Preview {
    HotCandidatesView()
}

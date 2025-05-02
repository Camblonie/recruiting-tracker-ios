import SwiftUI
import SwiftData
import Charts

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var filter = SearchFilter.empty
    @State private var sortOption = SortOption.nameAsc
    @State private var showingFilters = false
    @State private var selectedCandidate: Candidate?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Custom tab picker for sort options
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        sortOption = option
                                    }) {
                                        VStack(spacing: 4) {
                                            Text(option.rawValue)
                                                .font(.headline)
                                                .fontWeight(sortOption == option ? .bold : .regular)
                                                .foregroundColor(sortOption == option ? .white : .white.opacity(0.7))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                        }
                                        .background(
                                            sortOption == option ? 
                                                Color.slate : Color.slate.opacity(0.6)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .background(Color.headerGradient)
                    }
                    .frame(height: 44)
                    
                    CandidateSearchResults(
                        searchText: searchText,
                        filter: filter,
                        sortOption: sortOption,
                        selectedCandidate: $selectedCandidate,
                        showingDeleteConfirmation: $showingDeleteConfirmation
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search by name, email, or phone")
            .onChange(of: searchText) { oldValue, newValue in
                filter.searchText = newValue
            }
            .navigationTitle("Search")
            .toolbarBackground(Color.headerGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.cream)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: $filter, isPresented: $showingFilters)
            }
            .alert("Delete Candidate", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let candidate = selectedCandidate {
                        modelContext.delete(candidate)
                        selectedCandidate = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this candidate? This action cannot be undone.")
            }
        }
    }
}

struct CandidateSearchResults: View {
    let searchText: String
    let filter: SearchFilter
    let sortOption: SortOption
    @Binding var selectedCandidate: Candidate?
    @Binding var showingDeleteConfirmation: Bool
    
    @Query private var candidates: [Candidate]
    
    init(searchText: String, filter: SearchFilter, sortOption: SortOption, selectedCandidate: Binding<Candidate?>, showingDeleteConfirmation: Binding<Bool>) {
        self.searchText = searchText
        self.filter = filter
        self.sortOption = sortOption
        self._selectedCandidate = selectedCandidate
        self._showingDeleteConfirmation = showingDeleteConfirmation
        
        let predicate = filter.buildPredicate()
        let sortDescriptor = filter.sortDescriptor(option: sortOption)
        _candidates = Query(filter: predicate, sort: [sortDescriptor])
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Group candidates by position
                let groupedCandidates = Dictionary(grouping: candidates) { candidate in
                    candidate.position?.title ?? "No Position Assigned"
                }
                
                // Sort position keys alphabetically with "No Position" at the end
                let sortedPositions = groupedCandidates.keys.sorted { 
                    if $0 == "No Position Assigned" { return false }
                    if $1 == "No Position Assigned" { return true }
                    return $0 < $1
                }
                
                ForEach(sortedPositions, id: \.self) { positionName in
                    if let candidatesForPosition = groupedCandidates[positionName] {
                        Section(header: 
                            HStack {
                                Image(systemName: "briefcase.fill")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                
                                Text(positionName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.slate.opacity(0.9))
                                    .shadow(color: Color.slate.opacity(0.15), radius: 2, x: 0, y: 1)
                            )
                            .padding(.top, 4)
                        ) {
                            ForEach(candidatesForPosition) { candidate in
                                NavigationLink(destination: CandidateDetailView(candidate: candidate)) {
                                    CandidateRow(candidate: candidate)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                selectedCandidate = candidate
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.skyBlue.opacity(0.1))
        .overlay {
            if candidates.isEmpty {
                ContentUnavailableView.search
                    .background(Color.skyBlue.opacity(0.05))
            }
        }
    }
}

struct CandidateRow: View {
    let candidate: Candidate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(candidate.name)
                    .font(.headline)
                    .foregroundColor(Color.slate)
                
                Spacer()
                
                if candidate.isHotCandidate {
                    Label("Hot", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.terracotta)
                        .cornerRadius(4)
                }
                
                if candidate.needsFollowUp {
                    Label("Follow up", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.slate)
                        .cornerRadius(4)
                }
                
                if candidate.avoidCandidate {
                    Label("Avoid", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
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
                Spacer()
                Text(candidate.hiringStatus.rawValue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.slate.opacity(0.1))
                    .cornerRadius(4)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            Color.cream.opacity(0.7)
        )
        .cornerRadius(12)
        .shadow(color: Color.slate.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    private func levelIndicator(for level: TechnicianLevel) -> String {
        switch level {
        case .unknown:
            return "?"
        case .a:
            return "A"
        case .b:
            return "B"
        case .c:
            return "C"
        case .lubeTech:
            return "L"
        }
    }
    
    private func levelGradient(for level: TechnicianLevel) -> LinearGradient {
        switch level {
        case .unknown:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "8E8E93"), Color(hex: "AEAEB2")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .a:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "0A84FF"), Color(hex: "5AC8FA")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .b:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "5856D6"), Color(hex: "7D7AFF")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .c:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "34C759"), Color(hex: "30D158")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case .lubeTech:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "AF52DE"), Color(hex: "C969E6")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: Candidate.self, inMemory: true)
}

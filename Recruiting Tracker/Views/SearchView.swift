import SwiftUI
import SwiftData

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
            VStack(spacing: 0) {
                // Sort option picker
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search results
                CandidateSearchResults(
                    searchText: searchText,
                    filter: filter,
                    sortOption: sortOption,
                    selectedCandidate: $selectedCandidate,
                    showingDeleteConfirmation: $showingDeleteConfirmation
                )
            }
            .searchable(text: $searchText, prompt: "Search by name, email, or phone")
            .onChange(of: searchText) { oldValue, newValue in
                filter.searchText = newValue
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
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
        List {
            ForEach(candidates) { candidate in
                NavigationLink(destination: CandidateDetailView(candidate: candidate)) {
                    CandidateRow(candidate: candidate)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        selectedCandidate = candidate
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if candidates.isEmpty {
                ContentUnavailableView.search
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
                
                if candidate.isHotCandidate {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                }
                
                if candidate.needsFollowUp {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                }
                
                if candidate.avoidCandidate {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text(candidate.technicianLevel.rawValue)
                    .font(.caption)
                    .padding(4)
                    .background(levelColor(for: candidate.technicianLevel))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text(candidate.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(candidate.yearsOfExperience) years", systemImage: "clock")
                Spacer()
                Text(candidate.hiringStatus.rawValue)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func levelColor(for level: TechnicianLevel) -> Color {
        switch level {
        case .a:
            return .green
        case .b:
            return .blue
        case .c:
            return .orange
        case .lubeTech:
            return .purple
        }
    }
}

#Preview {
    SearchView()
}

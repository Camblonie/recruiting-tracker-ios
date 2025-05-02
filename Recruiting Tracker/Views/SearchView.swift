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
                    VStack {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(
                        Color.calmGradient
                            .opacity(0.15)
                    )
                    
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
                            Text(positionName)
                                .font(.headline)
                                .foregroundColor(.slate)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.cream.opacity(0.7))
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
                
                if candidate.isHotCandidate {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.terracotta)
                }
                
                if candidate.needsFollowUp {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.slate)
                }
                
                if candidate.avoidCandidate {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text(candidate.technicianLevel.rawValue)
                    .font(.caption)
                    .padding(4)
                    .background(levelGradient(for: candidate.technicianLevel))
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
            Group {
                if candidate.isHotCandidate {
                    Color.warmGradient
                        .opacity(0.7)
                } else if candidate.needsFollowUp {
                    Color.followUpGradient
                        .opacity(0.7)
                } else if candidate.avoidCandidate {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red.opacity(0.7), Color.red.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.neutralGradient
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: Color.slate.opacity(0.15), radius: 4, x: 0, y: 2)
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
    SearchView()
        .modelContainer(for: Candidate.self, inMemory: true)
}

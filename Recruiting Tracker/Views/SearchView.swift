import SwiftUI
import SwiftData
import Charts
import UIKit

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var filter = SearchFilter.empty
    @State private var sortOption = SortOption.nameAsc
    @State private var showingFilters = false
    @State private var selectedCandidate: Candidate?
    @State private var showingDeleteConfirmation = false
    // Refresh token to force view reloads when user pulls to refresh or taps Update
    @State private var refreshToken = UUID()
    
    var body: some View {
        NavigationStack {
            // Remove outer ScrollView so the inner results list controls scrolling
            // This keeps the A–Z index (overlayed inside results) stationary on screen.
            ZStack {
                Color.skyBlue.opacity(0.1).ignoresSafeArea()
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
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        // Wire pull-to-refresh to regenerate the view identity
                        onRefresh: { refreshToken = UUID() }
                    )
                    .id(refreshToken)
                }
            }
            // Stationary A–Z index overlay pinned to the right edge of the screen (applied to ZStack)
            .overlay(alignment: .trailing) {
                let alphabetLetters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }
                AlphabetIndexBar(
                    letters: alphabetLetters,
                    enabled: Set(alphabetLetters), // enable all; scrolling will no-op if no match
                    onTap: { letter in
                        NotificationCenter.default.post(
                            name: .didTapAlphabetIndex,
                            object: nil,
                            userInfo: ["letter": letter]
                        )
                    }
                )
                .padding(.trailing, 4)
                .padding(.vertical, 8)
                .ignoresSafeArea(.keyboard)
                .zIndex(100)
            }
            .searchable(text: $searchText, prompt: "Search by name, email, or phone")
            .onChange(of: searchText) { oldValue, newValue in
                filter.searchText = newValue
            }
            .navigationTitle("Recruiting Tracker")
            .toolbarBackground(Color.headerGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // Configure search bar text color while preserving background color
            .onAppear {
                // Set search text color to white
                UISearchBar.appearance().tintColor = .white
                UISearchBar.appearance().searchTextField.textColor = .white
                
                // Set the search bar icon color to white
                UISearchBar.appearance().searchTextField.leftView?.tintColor = .white
                
                // Ensure navigation bar title text is white
                let navBarAppearance = UINavigationBar.appearance()
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // Manual refresh via toolbar
                        refreshToken = UUID()
                    } label: {
                        Label("Update", systemImage: "arrow.clockwise")
                            .foregroundColor(.cream)
                    }

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
    // Optional pull-to-refresh callback provided by parent SearchView
    let onRefresh: (() -> Void)?
    
    @Query private var candidates: [Candidate]
    @Query private var companies: [Company]
    
    // Filtered candidates based on search text
    private var filteredCandidates: [Candidate] {
        if searchText.isEmpty {
            return candidates
        } else {
            return candidates.filter { candidate in
                let searchTermLowercased = searchText.lowercased()
                return candidate.name.lowercased().contains(searchTermLowercased) ||
                       candidate.email.lowercased().contains(searchTermLowercased) ||
                       candidate.phoneNumber.lowercased().contains(searchTermLowercased) ||
                       candidate.notes.lowercased().contains(searchTermLowercased)
            }
        }
    }
    
    init(searchText: String, filter: SearchFilter, sortOption: SortOption, selectedCandidate: Binding<Candidate?>, showingDeleteConfirmation: Binding<Bool>, onRefresh: (() -> Void)? = nil) {
        self.searchText = searchText
        self.filter = filter
        self.sortOption = sortOption
        self._selectedCandidate = selectedCandidate
        self._showingDeleteConfirmation = showingDeleteConfirmation
        self.onRefresh = onRefresh
        
        // Use a simple predicate (we'll filter by search text in the view)
        let predicate = #Predicate<Candidate> { _ in true }
        let sortDescriptor = filter.sortDescriptor(option: sortOption)
        _candidates = Query(filter: predicate, sort: [sortDescriptor])
    }
    
    var body: some View {
        // Helper to resolve the company name for a given candidate via its position
        func companyName(for candidate: Candidate) -> String {
            guard let pos = candidate.position else { return "" }
            return companies.first(where: { ($0.positions ?? []).contains(where: { $0 === pos }) })?.name ?? ""
        }

        // Build a flat, ordered list of candidates WITHOUT grouping/headers
        let orderedCandidates: [Candidate] = {
            switch sortOption {
            case .companyAsc:
                return filteredCandidates.sorted { a, b in
                    let ca = companyName(for: a)
                    let cb = companyName(for: b)
                    if ca.isEmpty && !cb.isEmpty { return false } // push empty to end
                    if !ca.isEmpty && cb.isEmpty { return true }
                    return ca.localizedCaseInsensitiveCompare(cb) == .orderedAscending
                }
            case .companyDesc:
                return filteredCandidates.sorted { a, b in
                    let ca = companyName(for: a)
                    let cb = companyName(for: b)
                    if ca.isEmpty && !cb.isEmpty { return false } // push empty to end
                    if !ca.isEmpty && cb.isEmpty { return true }
                    return ca.localizedCaseInsensitiveCompare(cb) == .orderedDescending
                }
            case .positionAsc:
                // Sort by position title; unassigned go last
                return filteredCandidates.sorted { a, b in
                    let atOpt = a.position?.title
                    let btOpt = b.position?.title
                    if atOpt == nil && btOpt != nil { return false }
                    if atOpt != nil && btOpt == nil { return true }
                    guard let at = atOpt, let bt = btOpt else { return false }
                    return at.localizedCaseInsensitiveCompare(bt) == .orderedAscending
                }
            case .positionDesc:
                return filteredCandidates.sorted { a, b in
                    let atOpt = a.position?.title
                    let btOpt = b.position?.title
                    if atOpt == nil && btOpt != nil { return false }
                    if atOpt != nil && btOpt == nil { return true }
                    guard let at = atOpt, let bt = btOpt else { return false }
                    return at.localizedCaseInsensitiveCompare(bt) == .orderedDescending
                }
            default:
                // For name/date/experience, rely on the SwiftData sort already applied to the query
                // and only filter on search text here.
                return filteredCandidates
            }
        }()

        // Build first anchor id for each letter based on FIRST NAME initial
        var firstIdForLetter: [String: String] = [:]
        for c in orderedCandidates {
            // Take first token (first name), then first letter
            if let firstToken = c.name.split(whereSeparator: { $0.isWhitespace }).first {
                let initial = String(firstToken).prefix(1).uppercased()
                if initial >= "A" && initial <= "Z" {
                    if firstIdForLetter[initial] == nil {
                        firstIdForLetter[initial] = c.id
                    }
                }
            }
        }
        // Stationary overlay in SearchView will broadcast taps; we'll scroll upon receiving notifications

        return ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(orderedCandidates) { candidate in
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
                            .id(candidate.id) // Anchor for ScrollViewReader
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    // Reserve space on the right so content never sits under the stationary A–Z index
                    .padding(.leading, 16)
                    .padding(.trailing, 56)
                    .padding(.vertical, 16)
                }
                // Enable pull-to-refresh on the scrolling content
                .refreshable {
                    onRefresh?()
                }
                .background(Color.skyBlue.opacity(0.1))
                
                // Empty state overlay
                if filteredCandidates.isEmpty {
                    ContentUnavailableView.search
                        .background(Color.skyBlue.opacity(0.05))
                }
            }
            // Listen for taps from the stationary A–Z index at SearchView level
            .onReceive(NotificationCenter.default.publisher(for: .didTapAlphabetIndex)) { note in
                if let letter = note.userInfo?["letter"] as? String, let target = firstIdForLetter[letter] {
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
            }
        }
    }
}

struct CandidateRow: View {
    let candidate: Candidate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                // Show split first/last while keeping combined name for headline
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
        .padding(8)
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
        case .salesAssoc:
            return "SA"
        case .manager:
            return "M"
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
}

#Preview {
    SearchView()
        .modelContainer(for: Candidate.self, inMemory: true)
}

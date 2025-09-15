import Foundation
import SwiftData

@Model
final class SearchFilter {
    // Date range filter
    @Transient var dateRange: ClosedRange<Date>?
    // MARK: - Properties
    var id: String
    var name: String
    var isActive: Bool
    
    // Search Criteria
    var searchText: String
    var leadSources: Set<LeadSource>
    var previousEmployers: Set<PreviousEmployer>
    var technicalFocus: Set<TechnicalFocus>
    var technicianLevels: Set<TechnicianLevel>
    var hiringStatuses: Set<HiringStatus>
    var yearsOfExperienceMin: Int?
    var yearsOfExperienceMax: Int?
    var needsHealthInsurance: Bool?
    var isHotCandidate: Bool?
    var needsFollowUp: Bool?
    var avoidCandidate: Bool?
    
    // MARK: - Initialization
    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.isActive = true
        
        // Initialize with empty/default values
        self.searchText = ""
        self.leadSources = []
        self.previousEmployers = []
        self.technicalFocus = []
        self.technicianLevels = []
        self.hiringStatuses = []
        self.yearsOfExperienceMin = nil
        self.yearsOfExperienceMax = nil
        self.needsHealthInsurance = nil
        self.isHotCandidate = nil
        self.needsFollowUp = nil
        self.avoidCandidate = nil
        self.dateRange = nil
    }
    
    // MARK: - Filter Methods
    /// Returns a simple `all true` predicate to use when no other criteria are set
    func buildPredicate() -> Predicate<Candidate> {
        // Use a simple predicate as a fallback for SwiftData querying
        return #Predicate<Candidate> { _ in true }
    }
    
    /// Gets filtered candidates by applying filters step by step
    /// Use this method instead of using the predicate directly
    func getFilteredCandidates(from modelContext: ModelContext) throws -> [Candidate] {
        // Start with a fetch of all candidates
        var candidates = try modelContext.fetch(FetchDescriptor<Candidate>())
        
        // Apply text search filter - check if any term matches any text field
        if !searchText.isEmpty {
            let terms = searchText.split(separator: " ").map(String.init)
            for term in terms {
                candidates = candidates.filter { candidate in
                    candidate.name.contains(term) ||
                    candidate.email.contains(term) ||
                    candidate.phoneNumber.contains(term) ||
                    candidate.notes.contains(term)
                }
            }
        }
        
        // Filter by lead sources
        if !leadSources.isEmpty {
            candidates = candidates.filter { candidate in
                leadSources.contains(candidate.leadSource)
            }
        }
        
        // Filter by previous employers
        if !previousEmployers.isEmpty {
            candidates = candidates.filter { candidate in
                candidate.previousEmployers.contains { employer in
                    previousEmployers.contains(employer)
                }
            }
        }
        
        // Filter by technical focus
        if !technicalFocus.isEmpty {
            candidates = candidates.filter { candidate in
                candidate.technicalFocus.contains { focus in
                    technicalFocus.contains(focus)
                }
            }
        }
        
        // Filter by technician levels
        if !technicianLevels.isEmpty {
            candidates = candidates.filter { candidate in
                technicianLevels.contains(candidate.technicianLevel)
            }
        }
        
        // Filter by hiring status
        if !hiringStatuses.isEmpty {
            candidates = candidates.filter { candidate in
                hiringStatuses.contains(candidate.hiringStatus)
            }
        }
        
        // Filter by years of experience
        if let min = yearsOfExperienceMin {
            candidates = candidates.filter { candidate in
                candidate.yearsOfExperience >= min
            }
        }
        
        if let max = yearsOfExperienceMax {
            candidates = candidates.filter { candidate in
                candidate.yearsOfExperience <= max
            }
        }
        
        // Filter by boolean properties
        if let value = needsHealthInsurance {
            candidates = candidates.filter { candidate in
                candidate.needsHealthInsurance == value
            }
        }
        
        if let value = isHotCandidate {
            candidates = candidates.filter { candidate in 
                candidate.isHotCandidate == value
            }
        }
        
        if let value = needsFollowUp {
            candidates = candidates.filter { candidate in
                candidate.needsFollowUp == value
            }
        }
        
        if let value = avoidCandidate {
            candidates = candidates.filter { candidate in
                candidate.avoidCandidate == value
            }
        }
        
        // Filter by date range
        if let range = dateRange {
            candidates = candidates.filter { candidate in
                range.contains(candidate.dateEntered)
            }
        }
        
        return candidates
    }
}

extension SearchFilter {
    /// Provides an empty filter for previews.
    static var empty: SearchFilter {
        let filter = SearchFilter(name: "")
        filter.isActive = false
        return filter
    }
}

// MARK: - Sort Options
enum SortOption: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case dateAddedNewest = "Date Added (Newest)"
    case dateAddedOldest = "Date Added (Oldest)"
    case experienceHighest = "Experience (Highest)"
    case experienceLowest = "Experience (Lowest)"
}

// MARK: - Sort Descriptors
extension SearchFilter {
    func sortDescriptor(option: SortOption) -> SortDescriptor<Candidate> {
        switch option {
        case .nameAsc:
            return SortDescriptor(\Candidate.name, order: .forward)
        case .nameDesc:
            return SortDescriptor(\Candidate.name, order: .reverse)
        case .dateAddedNewest:
            return SortDescriptor(\Candidate.dateEntered, order: .reverse)
        case .dateAddedOldest:
            return SortDescriptor(\Candidate.dateEntered, order: .forward)
        case .experienceHighest:
            return SortDescriptor(\Candidate.yearsOfExperience, order: .reverse)
        case .experienceLowest:
            return SortDescriptor(\Candidate.yearsOfExperience, order: .forward)
        }
    }
}

import Foundation
import SwiftData
import SwiftUI
import Charts

class StatisticsManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Basic Statistics
    
    func totalCandidates() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Candidate>())
    }
    
    func hotCandidates() throws -> Int {
        let descriptor = FetchDescriptor<Candidate>(
            predicate: #Predicate<Candidate> { $0.isHotCandidate }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    func needsFollowUp() throws -> Int {
        let descriptor = FetchDescriptor<Candidate>(
            predicate: #Predicate<Candidate> { $0.needsFollowUp }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    func avoidListCount() throws -> Int {
        let descriptor = FetchDescriptor<Candidate>(
            predicate: #Predicate<Candidate> { $0.avoidCandidate }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - Trend Analysis
    
    struct TrendData: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }
    
    func candidatesByMonth(months: Int = 12) throws -> [TrendData] {
        let descriptor = FetchDescriptor<Candidate>(
            sortBy: [SortDescriptor(\Candidate.dateEntered)]
        )
        let candidates = try modelContext.fetch(descriptor)
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -months + 1, to: now)!
        
        var monthlyData: [Date: Int] = [:]
        
        // Initialize all months with zero
        for monthOffset in 0..<months {
            let month = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
            let normalizedMonth = calendar.startOfMonth(for: month)
            monthlyData[normalizedMonth] = 0
        }
        
        // Count candidates by month
        for candidate in candidates {
            let month = calendar.startOfMonth(for: candidate.dateEntered)
            if month >= startDate {
                monthlyData[month, default: 0] += 1
            }
        }
        
        // Convert dictionary to array of TrendData
        var result: [TrendData] = []
        let sortedData = monthlyData.sorted { $0.key < $1.key }
        for item in sortedData {
            result.append(TrendData(date: item.key, count: item.value))
        }
        return result
    }
    
    // MARK: - Distribution Analysis
    
    struct DistributionData: Identifiable {
        let id = UUID()
        let category: String
        let count: Int
        let percentage: Double
    }
    
    func leadSourceDistribution() throws -> [DistributionData] {
        let descriptor = FetchDescriptor<Candidate>()
        var candidates: [Candidate] = []
        do {
            candidates = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching candidates for lead sources: \(error)")
            return []
        }
        
        let total = Double(candidates.count)
        
        var distribution: [LeadSource: Int] = [:]
        LeadSource.allCases.forEach { source in
            distribution[source] = 0
        }
        
        for candidate in candidates {
            distribution[candidate.leadSource, default: 0] += 1
        }
        
        // Convert dictionary to array of DistributionData
        var result: [DistributionData] = []
        for (source, count) in distribution {
            result.append(DistributionData(
                category: source.rawValue,
                count: count,
                percentage: total > 0 ? Double(count) / total * 100 : 0
            ))
        }
        // Sort by count in descending order
        result.sort { $0.count > $1.count }
        return result
    }
    
    func technicianLevelDistribution() throws -> [DistributionData] {
        let descriptor = FetchDescriptor<Candidate>()
        var candidates: [Candidate] = []
        do {
            candidates = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching candidates: \(error)")
            return []
        }
        
        let total = Double(candidates.count)
        
        var distribution: [TechnicianLevel: Int] = [:]
        TechnicianLevel.allCases.forEach { level in
            distribution[level] = 0
        }
        
        for candidate in candidates {
            distribution[candidate.technicianLevel, default: 0] += 1
        }
        
        // Convert dictionary to array of DistributionData
        var result: [DistributionData] = []
        for (level, count) in distribution {
            result.append(DistributionData(
                category: level.rawValue,
                count: count,
                percentage: total > 0 ? Double(count) / total * 100 : 0
            ))
        }
        // Sort by count in descending order
        result.sort { $0.count > $1.count }
        return result
    }
    
    func hiringStatusDistribution() throws -> [DistributionData] {
        let descriptor = FetchDescriptor<Candidate>()
        var candidates: [Candidate] = []
        do {
            candidates = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching candidates for hiring status: \(error)")
            return []
        }
        
        let total = Double(candidates.count)
        
        var distribution: [HiringStatus: Int] = [:]
        HiringStatus.allCases.forEach { status in
            distribution[status] = 0
        }
        
        for candidate in candidates {
            distribution[candidate.hiringStatus, default: 0] += 1
        }
        
        // Convert dictionary to array of DistributionData
        var result: [DistributionData] = []
        for (status, count) in distribution {
            result.append(DistributionData(
                category: status.rawValue,
                count: count,
                percentage: total > 0 ? Double(count) / total * 100 : 0
            ))
        }
        // Sort by count in descending order
        result.sort { $0.count > $1.count }
        return result
    }
    
    func experienceDistribution() throws -> [DistributionData] {
        let descriptor = FetchDescriptor<Candidate>()
        let candidates = try modelContext.fetch(descriptor)
        let total = Double(candidates.count)
        
        var distribution: [String: Int] = [
            "0-2": 0,
            "3-5": 0,
            "6-10": 0,
            "11-15": 0,
            "16+": 0
        ]
        
        for candidate in candidates {
            let years = candidate.yearsOfExperience
            switch years {
            case 0...2:
                distribution["0-2"]! += 1
            case 3...5:
                distribution["3-5"]! += 1
            case 6...10:
                distribution["6-10"]! += 1
            case 11...15:
                distribution["11-15"]! += 1
            default:
                distribution["16+"]! += 1
            }
        }
        
        // Convert dictionary to array of DistributionData
        var result: [DistributionData] = []
        for (range, count) in distribution {
            result.append(DistributionData(
                category: range,
                count: count,
                percentage: total > 0 ? Double(count) / total * 100 : 0
            ))
        }
        // Sort by category name
        result.sort { $0.category < $1.category }
        return result
    }
    
    // MARK: - Insights
    
    struct Insight {
        let title: String
        let value: String
        let trend: String
        let color: Color
    }
    
    func generateInsights() throws -> [Insight] {
        var insights: [Insight] = []
        
        // Calculate basic metrics
        let total = try totalCandidates()
        
        // Guard against empty data
        guard total > 0 else {
            return [
                Insight(
                    title: "Total Candidates",
                    value: "0",
                    trend: "No data yet",
                    color: .gray
                ),
                Insight(
                    title: "Hot Candidates",
                    value: "0",
                    trend: "No data yet",
                    color: .gray
                ),
                Insight(
                    title: "Need Follow-up",
                    value: "0",
                    trend: "No data yet",
                    color: .gray
                ),
                Insight(
                    title: "Avoid List",
                    value: "0",
                    trend: "No data yet",
                    color: .gray
                )
            ]
        }
        
        // Only fetch these if we have candidates
        let hot = try hotCandidates()
        let followUp = try needsFollowUp()
        let avoid = try avoidListCount()
        
        // Get monthly trends
        let trends = try candidatesByMonth(months: 3)
        
        // Safely calculate trend
        let trend: Double
        if trends.count >= 2, let currentMonth = trends.last?.count, let previousMonth = trends.dropLast().last?.count, previousMonth > 0 {
            trend = Double(currentMonth) / Double(previousMonth)
        } else {
            trend = 1.0
        }
        
        // Add insights
        insights.append(Insight(
            title: "Total Candidates",
            value: "\(total)",
            trend: trend > 1 ? "↑" : trend < 1 ? "↓" : "→",
            color: trend > 1 ? .green : trend < 1 ? .red : .blue
        ))
        
        insights.append(Insight(
            title: "Hot Candidates",
            value: "\(hot)",
            trend: total > 0 ? "\(Int((Double(hot) / Double(total) * 100)))%" : "0%",
            color: .orange
        ))
        
        insights.append(Insight(
            title: "Need Follow-up",
            value: "\(followUp)",
            trend: total > 0 ? "\(Int((Double(followUp) / Double(total) * 100)))%" : "0%",
            color: .blue
        ))
        
        insights.append(Insight(
            title: "Avoid List",
            value: "\(avoid)",
            trend: total > 0 ? "\(Int((Double(avoid) / Double(total) * 100)))%" : "0%",
            color: .red
        ))
        
        return insights
    }
}

// MARK: - Helper Extensions

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

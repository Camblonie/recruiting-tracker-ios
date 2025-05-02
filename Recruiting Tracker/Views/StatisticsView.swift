import SwiftUI
import SwiftData
import Charts

// MARK: - Chart Color Palette
extension Color {
    /// Predefined colors for charts.
    static let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .red, .pink, .yellow
    ]
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTimeRange = TimeRange.year
    @State private var selectedChart = ChartType.trend
    @State private var statistics: StatisticsManager?
    @State private var insights: [StatisticsManager.Insight] = []
    @State private var trendData: [StatisticsManager.TrendData] = []
    @State private var leadSourceData: [StatisticsManager.DistributionData] = []
    @State private var techLevelData: [StatisticsManager.DistributionData] = []
    @State private var hiringStatusData: [StatisticsManager.DistributionData] = []
    @State private var experienceData: [StatisticsManager.DistributionData] = []
    
    enum TimeRange: String, CaseIterable {
        case month = "30 Days"
        case quarter = "90 Days"
        case year = "12 Months"
    }
    
    enum ChartType: String, CaseIterable {
        case trend = "Trends"
        case leadSource = "Lead Sources"
        case techLevel = "Tech Levels"
        case hiringStatus = "Hiring Status"
        case experience = "Experience"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Insights Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(insights, id: \.title) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding()
                    
                    // Chart Controls
                    VStack {
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("Chart Type", selection: $selectedChart) {
                            ForEach(ChartType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Charts
                    Group {
                        switch selectedChart {
                        case .trend:
                            TrendChart(data: trendData)
                        case .leadSource:
                            DistributionChart(
                                title: "Lead Sources",
                                data: leadSourceData
                            )
                        case .techLevel:
                            DistributionChart(
                                title: "Technician Levels",
                                data: techLevelData
                            )
                        case .hiringStatus:
                            DistributionChart(
                                title: "Hiring Status",
                                data: hiringStatusData
                            )
                        case .experience:
                            DistributionChart(
                                title: "Years of Experience",
                                data: experienceData
                            )
                        }
                    }
                    .frame(height: 300)
                    .padding()
                }
            }
            .navigationTitle("Statistics")
            .onAppear {
                statistics = StatisticsManager(modelContext: modelContext)
                refreshData()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                refreshData()
            }
            .refreshable {
                refreshData()
            }
        }
    }
    
    private func refreshData() {
        Task {
            do {
                guard let stats = statistics else { return }
                
                var insights: [StatisticsManager.Insight] = []
                var trend: [StatisticsManager.TrendData] = []
                var leadSource: [StatisticsManager.DistributionData] = []
                var techLevel: [StatisticsManager.DistributionData] = []
                var hiringStatus: [StatisticsManager.DistributionData] = []
                var experience: [StatisticsManager.DistributionData] = []
                
                // First check if there are any candidates
                let total = try stats.totalCandidates()
                if total == 0 {
                    // No candidates - use placeholder data instead of running concurrent tasks
                    insights = try stats.generateInsights()
                    self.insights = insights
                    self.trendData = []
                    self.leadSourceData = []  
                    self.techLevelData = []
                    self.hiringStatusData = []
                    self.experienceData = []
                    return
                }
                
                // Continue with normal processing if we have candidates
                let months: Int
                switch selectedTimeRange {
                case .month:
                    months = 1
                case .quarter:
                    months = 3
                case .year:
                    months = 12
                }
                
                // Use try-catch for each individual task to prevent a single failure from freezing everything
                do {
                    insights = try await stats.generateInsights()
                } catch {
                    print("Error generating insights: \(error)")
                }
                 
                do {
                    trend = try await stats.candidatesByMonth(months: months)
                } catch {
                    print("Error generating trend data: \(error)")
                }
                
                do {
                    leadSource = try await stats.leadSourceDistribution()
                } catch {
                    print("Error generating lead source data: \(error)")
                }
                
                do {
                    techLevel = try await stats.technicianLevelDistribution()
                } catch {
                    print("Error generating tech level data: \(error)")
                }
                
                do {
                    hiringStatus = try await stats.hiringStatusDistribution()
                } catch {
                    print("Error generating hiring status data: \(error)")
                }
                
                do {
                    experience = try await stats.experienceDistribution()
                } catch {
                    print("Error generating experience data: \(error)")
                }
                
                self.insights = insights
                self.trendData = trend
                self.leadSourceData = leadSource
                self.techLevelData = techLevel
                self.hiringStatusData = hiringStatus
                self.experienceData = experience
                
            } catch {
                print("Error refreshing statistics: \(error)")
            }
        }
    }
}

struct InsightCard: View {
    let insight: StatisticsManager.Insight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(insight.value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(insight.trend)
                    .font(.caption)
                    .padding(4)
                    .background(insight.color.opacity(0.2))
                    .foregroundColor(insight.color)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TrendChart: View {
    let data: [StatisticsManager.TrendData]
    
    var body: some View {
        Chart {
            ForEach(data) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Count", item.count)
                )
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct DistributionChart: View {
    let title: String
    let data: [StatisticsManager.DistributionData]
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                BarMark(
                    x: .value("Category", item.category),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Color.chartColors[index % Color.chartColors.count])
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let category = value.as(String.self) {
                        Text(category)
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

#Preview {
    StatisticsView()
}

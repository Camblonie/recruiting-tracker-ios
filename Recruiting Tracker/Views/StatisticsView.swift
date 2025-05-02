import SwiftUI
import SwiftData
import Charts

// MARK: - Chart Color Palette
extension Color {
    /// Predefined colors for charts.
    static let chartColors: [Color] = [
        .terracotta, .slate, .skyBlue, .cream, 
        Color(hex: "E58E65"), // Light terracotta
        Color(hex: "6D8B9C"), // Light slate
        Color(hex: "A3C2D1")  // Light skyBlue
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
            ZStack {
                // Background
                Color.skyBlue.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Insights Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(insights, id: \.title) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Chart Controls
                        VStack(spacing: 12) {
                            Picker("Time Range", selection: $selectedTimeRange) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(8)
                            .background(Color.cream.opacity(0.3))
                            .cornerRadius(8)
                            
                            Picker("Chart Type", selection: $selectedChart) {
                                ForEach(ChartType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(8)
                            .background(Color.cream.opacity(0.3))
                            .cornerRadius(8)
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
                        .frame(height: 350)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .background(Color.cream.opacity(0.15))
                        .cornerRadius(12)
                        .padding()
                        .shadow(color: Color.slate.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .navigationTitle("Statistics")
                .toolbarBackground(Color.headerGradient, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
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
                    insights = try stats.generateInsights()
                } catch {
                    print("Error generating insights: \(error)")
                }
                 
                do {
                    trend = try stats.candidatesByMonth(months: months)
                } catch {
                    print("Error generating trend data: \(error)")
                }
                
                do {
                    leadSource = try stats.leadSourceDistribution()
                } catch {
                    print("Error generating lead source data: \(error)")
                }
                
                do {
                    techLevel = try stats.technicianLevelDistribution()
                } catch {
                    print("Error generating tech level data: \(error)")
                }
                
                do {
                    hiringStatus = try stats.hiringStatusDistribution()
                } catch {
                    print("Error generating hiring status data: \(error)")
                }
                
                do {
                    experience = try stats.experienceDistribution()
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
                .foregroundColor(.slate.opacity(0.8))
            
            HStack {
                Text(insight.value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.slate)
                
                Spacer()
                
                Text(insight.trend)
                    .font(.caption)
                    .padding(4)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [insight.color.opacity(0.7), insight.color.opacity(0.4)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(insight.color)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color.cream.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.slate.opacity(0.15), radius: 3, x: 0, y: 2)
    }
}

struct TrendChart: View {
    let data: [StatisticsManager.TrendData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Candidate Trends")
                .font(.headline)
                .foregroundColor(.slate)
                .padding(.horizontal)
            
            Chart {
                ForEach(data) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Count", item.count)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.terracotta)
                    
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.terracotta.opacity(0.3), Color.terracotta.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                        .foregroundStyle(Color.slate.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.slate)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                        .foregroundStyle(Color.slate.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month())
                        .foregroundStyle(Color.slate)
                }
            }
            .frame(height: 280)
            .padding(.top, 8)
        }
    }
}

struct DistributionChart: View {
    let title: String
    let data: [StatisticsManager.DistributionData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(.slate)
                .padding(.horizontal)
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.chartColors[index % Color.chartColors.count],
                                Color.chartColors[index % Color.chartColors.count].opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                        .foregroundStyle(Color.slate.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.slate)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let category = value.as(String.self) {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.slate)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.top, 8)
        }
    }
}

#Preview {
    StatisticsView()
}

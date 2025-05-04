import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingCandidateForm = false
    
    var body: some View {
        ZStack {
            // Background to ensure our theme colors extend beyond tab area
            Color.skyBlue.opacity(0.1).ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                SearchView()
                    .tabItem {
                        Label("Recruiting Tracker", systemImage: "magnifyingglass")
                    }
                    .tag(0)

                FollowUpView()
                    .tabItem {
                        Label("Follow Up", systemImage: "bell")
                    }
                    .tag(1)

                // Add Candidate Tab
                ZStack {
                    // Background
                    Color.skyBlue.opacity(0.1).ignoresSafeArea()
                    
                    VStack {
                        Text("Add New Candidate")
                            .font(.title2)
                            .foregroundColor(.slate)
                            .padding(.top, 40)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCandidateForm = true
                        }) {
                            VStack(spacing: 16) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.terracotta)
                                
                                Text("Tap to Add Candidate")
                                    .font(.headline)
                                    .foregroundColor(.slate)
                            }
                            .padding(40)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.cream.opacity(0.7))
                            )
                            .shadow(color: Color.slate.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding()
                        
                        Spacer()
                        Spacer()
                    }
                }
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
                .tag(2)
                .sheet(isPresented: $showingCandidateForm) {
                    NavigationView {
                        CandidateFormView(isPresented: $showingCandidateForm)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }

                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }
            .onAppear {
                // Set TabView colors
                let appearance = UITabBarAppearance()
                appearance.backgroundColor = UIColor(Color.slate.opacity(0.95))
                
                let itemAppearance = UITabBarItemAppearance()
                // Unselected tab item
                itemAppearance.normal.iconColor = UIColor(Color.cream.opacity(0.6))
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.cream.opacity(0.6))]
                
                // Selected tab item
                itemAppearance.selected.iconColor = UIColor(Color.terracotta)
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.terracotta)]
                
                appearance.stackedLayoutAppearance = itemAppearance
                appearance.inlineLayoutAppearance = itemAppearance
                appearance.compactInlineLayoutAppearance = itemAppearance
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

#Preview {
    MainTabView()
}

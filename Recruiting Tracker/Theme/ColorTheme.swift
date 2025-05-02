import SwiftUI

// MARK: - Theme Colors
extension Color {
    // Primary Colors
    static let terracotta = Color(hex: "DD6E42") // Warm accent color for primary actions and hot candidates
    static let cream = Color(hex: "E8DAB2")      // Light background color for cards and secondary elements
    static let slate = Color(hex: "4F6D7A")      // Main content color for text and icons
    static let skyBlue = Color(hex: "C0D6DF")    // Secondary background color and highlights
    
    // Gradient Combinations
    static let warmGradient = LinearGradient(
        gradient: Gradient(colors: [.terracotta, .terracotta.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let calmGradient = LinearGradient(
        gradient: Gradient(colors: [.slate, .skyBlue]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let neutralGradient = LinearGradient(
        gradient: Gradient(colors: [.cream, .cream.opacity(0.7)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [.terracotta.opacity(0.8), .slate.opacity(0.8)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let headerGradient = LinearGradient(
        gradient: Gradient(colors: [.slate, .slate.opacity(0.8)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Status color gradients
    static let hotCandidateGradient = LinearGradient(
        gradient: Gradient(colors: [.terracotta, Color(hex: "E58E65")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let followUpGradient = LinearGradient(
        gradient: Gradient(colors: [.skyBlue, Color(hex: "A3C2D1")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Initialize a Color using a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Modifiers
extension View {
    // Apply primary button styling with terracotta gradient
    func primaryButtonStyle() -> some View {
        self
            .padding()
            .background(Color.warmGradient)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: Color.slate.opacity(0.3), radius: 3, x: 1, y: 2)
    }
    
    // Apply secondary button styling with slate gradient
    func secondaryButtonStyle() -> some View {
        self
            .padding()
            .background(Color.calmGradient)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: Color.slate.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // Apply card styling with cream background
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cream)
            .cornerRadius(12)
            .shadow(color: Color.slate.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    // Apply hot candidate styling
    func hotCandidateStyle() -> some View {
        self
            .padding()
            .background(Color.hotCandidateGradient)
            .cornerRadius(12)
            .shadow(color: Color.terracotta.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // Apply header styling
    func headerStyle() -> some View {
        self
            .padding()
            .background(Color.headerGradient)
            .foregroundColor(.white)
            .cornerRadius(0)
    }
}

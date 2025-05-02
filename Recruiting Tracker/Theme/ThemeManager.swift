import SwiftUI

// MARK: - ThemeManager
/// Manages appearance settings for the app
class ThemeManager {
    static let shared = ThemeManager()
    
    // MARK: - Card Styles
    
    /// Style for a standard candidate card
    func standardCardStyle(isEven: Bool = false) -> CardModifier {
        CardModifier(
            backgroundColor: isEven ? Color.cream : Color.cream.opacity(0.8), 
            shadowRadius: 3
        )
    }
    
    /// Style for a hot candidate card
    func hotCandidateCardStyle() -> CardModifier {
        CardModifier(
            backgroundGradient: Color.hotCandidateGradient,
            shadowColor: Color.terracotta.opacity(0.4),
            shadowRadius: 4
        )
    }
    
    /// Style for a card requiring follow up
    func followUpCardStyle() -> CardModifier {
        CardModifier(
            backgroundGradient: Color.followUpGradient,
            shadowColor: Color.skyBlue.opacity(0.4),
            shadowRadius: 4
        )
    }
    
    // MARK: - Button Styles
    
    /// Primary action button style
    func primaryButtonStyle() -> ButtonModifier {
        ButtonModifier(
            backgroundGradient: Color.warmGradient,
            textColor: .white,
            cornerRadius: 10,
            shadowRadius: 3
        )
    }
    
    /// Secondary action button style
    func secondaryButtonStyle() -> ButtonModifier {
        ButtonModifier(
            backgroundGradient: Color.calmGradient,
            textColor: .white,
            cornerRadius: 10,
            shadowRadius: 2
        )
    }
    
    /// Neutral button style for less important actions
    func neutralButtonStyle() -> ButtonModifier {
        ButtonModifier(
            backgroundGradient: Color.neutralGradient,
            textColor: Color.slate,
            cornerRadius: 8,
            shadowRadius: 1
        )
    }
    
    // MARK: - List & Section Styles
    
    /// Style for section headers
    func sectionHeaderStyle() -> SectionHeaderModifier {
        SectionHeaderModifier(
            backgroundGradient: Color.headerGradient,
            textColor: .white,
            fontSize: 18,
            fontWeight: .semibold
        )
    }
    
    /// Style for list backgrounds
    func listBackgroundStyle() -> BackgroundModifier {
        BackgroundModifier(backgroundColor: Color.skyBlue.opacity(0.15))
    }
}

// MARK: - Custom View Modifiers

struct CardModifier: ViewModifier {
    var backgroundColor: Color? = nil
    var backgroundGradient: LinearGradient? = nil
    var shadowColor: Color = Color.slate.opacity(0.2)
    var shadowRadius: CGFloat = 3
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                Group {
                    if let gradient = backgroundGradient {
                        gradient
                    } else {
                        backgroundColor ?? Color.white
                    }
                }
            )
            .cornerRadius(12)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
    }
}

struct ButtonModifier: ViewModifier {
    var backgroundGradient: LinearGradient
    var textColor: Color
    var cornerRadius: CGFloat = 10
    var shadowRadius: CGFloat = 3
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundGradient)
            .foregroundColor(textColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.slate.opacity(0.3),
                radius: shadowRadius,
                x: 1,
                y: 2
            )
    }
}

struct SectionHeaderModifier: ViewModifier {
    var backgroundGradient: LinearGradient
    var textColor: Color
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .medium
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(textColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundGradient)
            .cornerRadius(8)
    }
}

struct BackgroundModifier: ViewModifier {
    var backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
    }
}

// MARK: - View Extensions
extension View {
    /// Apply standard card styling
    func standardCard(isEven: Bool = false) -> some View {
        self.modifier(ThemeManager.shared.standardCardStyle(isEven: isEven))
    }
    
    /// Apply hot candidate card styling
    func hotCandidateCard() -> some View {
        self.modifier(ThemeManager.shared.hotCandidateCardStyle())
    }
    
    /// Apply follow-up card styling
    func followUpCard() -> some View {
        self.modifier(ThemeManager.shared.followUpCardStyle())
    }
    
    /// Apply primary button styling
    func primaryButton() -> some View {
        self.modifier(ThemeManager.shared.primaryButtonStyle())
    }
    
    /// Apply secondary button styling
    func secondaryButton() -> some View {
        self.modifier(ThemeManager.shared.secondaryButtonStyle())
    }
    
    /// Apply neutral button styling
    func neutralButton() -> some View {
        self.modifier(ThemeManager.shared.neutralButtonStyle())
    }
    
    /// Apply section header styling
    func sectionHeader() -> some View {
        self.modifier(ThemeManager.shared.sectionHeaderStyle())
    }
    
    /// Apply list background styling
    func listBackground() -> some View {
        self.modifier(ThemeManager.shared.listBackgroundStyle())
    }
}

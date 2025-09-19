import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isOnboarding: Bool
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    
    @State private var currentStep = 0
    @State private var companyName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var companyIcon: Data?
    @State private var positionTitle = ""
    @State private var positionDescription = ""
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    var body: some View {
        ZStack {
            // Background gradient that covers the entire screen
            LinearGradient(
                gradient: Gradient(colors: [Color.skyBlue.opacity(0.2), Color.cream.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentStep) {
                    welcomeView
                        .tag(0)
                    
                    companySetupView
                        .tag(1)
                    
                    positionSetupView
                        .tag(2)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button(action: handleContinue) {
                    Text(currentStep == 2 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            canContinue
                            ? AnyShapeStyle(Color.warmGradient)
                            : AnyShapeStyle(Color.slate.opacity(0.3))
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.slate.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage.isEmpty ? "Failed to save onboarding data. Please try again." : saveErrorMessage)
        }
    }
    
    var canContinue: Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            return !companyName.isEmpty
        case 2:
            return !positionTitle.isEmpty && !positionDescription.isEmpty
        default:
            return false
        }
    }
    
    var welcomeView: some View {
        VStack(spacing: 30) {
            // Logo/Icon with animation
            ZStack {
                Circle()
                    .fill(Color.calmGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.slate.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)
            
            // Title with gradient text
            Text("Welcome to\nRecruiting Tracker")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.slate, Color.terracotta],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Subtitle with custom styling
            Text("Let's set up your recruiting workspace")
                .font(.title3)
                .foregroundColor(.slate.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                
            // Feature highlights with icons
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "person.fill.checkmark", text: "Track candidate progress")
                FeatureRow(icon: "flame.fill", text: "Identify hot candidates")
                FeatureRow(icon: "chart.bar.fill", text: "Analyze recruitment metrics")
            }
            .padding(.top, 20)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cream.opacity(0.7))
                .shadow(color: Color.slate.opacity(0.2), radius: 15, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
    
    var companySetupView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Company Setup")
                .font(.title)
                .bold()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.slate, Color.slate.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Enter your company information")
                .font(.subheadline)
                .foregroundColor(.slate.opacity(0.7))
            
            TextField("Company Name", text: $companyName)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.slate.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 10)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                if let companyIcon = companyIcon,
                   let uiImage = UIImage(data: companyIcon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.slate.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.slate.opacity(0.3), radius: 5, x: 0, y: 2)
                } else {
                    Label("Select Company Icon", systemImage: "building.2")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.slate.opacity(0.1))
                        .foregroundColor(.slate)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.slate.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cream.opacity(0.7))
                .shadow(color: Color.slate.opacity(0.2), radius: 15, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    companyIcon = data
                }
            }
        }
    }
    
    var positionSetupView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Create Your First Position")
                .font(.title)
                .bold()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.slate, Color.slate.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Define a position you're recruiting for")
                .font(.subheadline)
                .foregroundColor(.slate.opacity(0.7))
                .padding(.bottom, 8)
            
            TextField("Position Title", text: $positionTitle)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.slate.opacity(0.3), lineWidth: 1)
                )
                .padding(.vertical, 4)
            
            TextField("Position Description", text: $positionDescription, axis: .vertical)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.slate.opacity(0.3), lineWidth: 1)
                )
                .frame(height: 120)
                .padding(.vertical, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cream.opacity(0.7))
                .shadow(color: Color.slate.opacity(0.2), radius: 15, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
    
    private func handleContinue() {
        if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Save company and position
            let company = Company(name: companyName, icon: companyIcon)
            let position = Position(title: positionTitle, positionDescription: positionDescription)
            company.positions.append(position)
            modelContext.insert(company)
            
            // Explicitly save the context
            do {
                try modelContext.save()
                print("Company and position saved successfully")
                // Mark onboarding complete only on successful save
                didCompleteOnboarding = true
                isOnboarding = false
            } catch {
                print("Error saving company: \(error)")
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
        }
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.terracotta)
                .frame(width: 30, height: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(Color.slate)
        }
    }
}

#Preview {
    OnboardingView(isOnboarding: .constant(true))
}

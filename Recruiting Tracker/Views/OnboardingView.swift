import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isOnboarding: Bool
    
    @State private var currentStep = 0
    @State private var companyName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var companyIcon: Data?
    @State private var positionTitle = ""
    @State private var positionDescription = ""
    
    var body: some View {
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
                        ? Color.blue
                        : Color.gray
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canContinue)
            .padding()
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
        VStack(spacing: 20) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to Recruiting Tracker")
                .font(.title)
                .bold()
            
            Text("Let's set up your recruiting workspace")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    var companySetupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Company Setup")
                .font(.title2)
                .bold()
            
            Text("Enter your company information")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Company Name", text: $companyName)
                .textFieldStyle(.roundedBorder)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                if let companyIcon = companyIcon,
                   let uiImage = UIImage(data: companyIcon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .cornerRadius(10)
                } else {
                    Label("Select Company Icon", systemImage: "building.2")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    companyIcon = data
                }
            }
        }
    }
    
    var positionSetupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create Your First Position")
                .font(.title2)
                .bold()
            
            Text("Define a position you're recruiting for")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Position Title", text: $positionTitle)
                .textFieldStyle(.roundedBorder)
            
            TextField("Position Description", text: $positionDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...6)
        }
        .padding()
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
            } catch {
                print("Error saving company: \(error)")
            }
            
            // End onboarding
            isOnboarding = false
        }
    }
}

#Preview {
    OnboardingView(isOnboarding: .constant(true))
}

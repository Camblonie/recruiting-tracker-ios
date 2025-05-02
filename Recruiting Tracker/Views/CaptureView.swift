import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingForm = false
    
    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    isShowingForm = true
                }) {
                    Label("Add New Candidate", systemImage: "person.badge.plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
                
                Spacer()
                
                Text("Start by adding a new candidate")
                    .foregroundColor(.gray)
            }
            .navigationTitle("Capture")
            .sheet(isPresented: $isShowingForm) {
                CandidateFormView(isPresented: $isShowingForm)
            }
        }
    }
}

#Preview {
    CaptureView()
}

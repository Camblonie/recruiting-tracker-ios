import SwiftUI
import SwiftData

struct CandidateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let candidate: Candidate
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAvoidWarning = false
    @State private var showingAvoidHistory = false
    @State private var avoidFlagReason = ""
    @State private var tempAvoidFlag = false
    
    var body: some View {
        List {
            // Basic Information
            Section("Basic Information") {
                LabeledContent("Name", value: candidate.name)
                LabeledContent("Phone", value: candidate.phoneNumber)
                LabeledContent("Email", value: candidate.email)
                LabeledContent("Lead Source", value: candidate.leadSource.rawValue)
                if let referralName = candidate.referralName {
                    LabeledContent("Referred By", value: referralName)
                }
            }
            
            // Experience
            Section("Experience") {
                LabeledContent("Years of Experience", value: "\(candidate.yearsOfExperience)")
                LabeledContent("Technician Level", value: candidate.technicianLevel.rawValue)
                
                DisclosureGroup("Previous Employers") {
                    ForEach(candidate.previousEmployers, id: \.self) { employer in
                        Text(employer.rawValue)
                    }
                }
                
                DisclosureGroup("Technical Focus") {
                    ForEach(candidate.technicalFocus, id: \.self) { focus in
                        Text(focus.rawValue)
                    }
                }
            }
            
            // Status
            Section("Status") {
                LabeledContent("Hiring Status", value: candidate.hiringStatus.rawValue)
                Toggle("Needs Follow-up", isOn: .constant(candidate.needsFollowUp))
                Toggle("Hot Candidate", isOn: .constant(candidate.isHotCandidate))
                
                Toggle("Avoid Candidate", isOn: Binding(
                    get: { candidate.avoidCandidate },
                    set: { newValue in
                        tempAvoidFlag = newValue
                        if newValue {
                            showingAvoidWarning = true
                        } else {
                            // If turning off, show warning if there's history
                            if !candidate.avoidFlagHistory.isEmpty {
                                showingAvoidWarning = true
                            } else {
                                candidate.updateAvoidFlag(to: newValue)
                            }
                        }
                    }
                ))
                
                if !candidate.avoidFlagHistory.isEmpty {
                    Button("View Avoid Flag History") {
                        showingAvoidHistory = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Compensation
            Section("Compensation") {
                if let payScale = candidate.conceptPayScale {
                    LabeledContent("Pay Scale", value: payScale)
                }
                if let payDate = candidate.conceptPayDate {
                    LabeledContent("Pay Scale Date", value: payDate.formatted(date: .numeric, time: .omitted))
                }
                LabeledContent("Needs Insurance", value: candidate.needsHealthInsurance ? "Yes" : "No")
            }
            
            // Additional Information
            Section("Additional Information") {
                if let offerDetail = candidate.offerDetail {
                    Text("Offer Details: \(offerDetail)")
                }
                
                if let offerDate = candidate.offerDate {
                    LabeledContent("Offer Date", value: offerDate.formatted(date: .numeric, time: .omitted))
                }
                
                if !candidate.socialMediaLinks.isEmpty {
                    DisclosureGroup("Social Media Links") {
                        ForEach(candidate.socialMediaLinks, id: \.self) { link in
                            Text(link)
                        }
                    }
                }
                
                if !candidate.notes.isEmpty {
                    DisclosureGroup("Notes") {
                        Text(candidate.notes)
                    }
                }
                
                LabeledContent("Date Entered", value: candidate.dateEntered.formatted(date: .numeric, time: .omitted))
            }
            
            // Actions
            Section {
                NavigationLink("Attached Files") {
                    FileAttachmentView(candidate: candidate)
                }
                
                Button("Share Candidate Info") {
                    shareCandidate()
                }
                .foregroundColor(.blue)
                
                Button("Delete Candidate", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(candidate.name)
        .alert("Delete Candidate", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteCandidate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this candidate? This action cannot be undone.")
        }
        .alert("Avoid Candidate Flag", isPresented: $showingAvoidWarning) {
            TextField("Reason for change", text: $avoidFlagReason)
            Button("Cancel", role: .cancel) {
                tempAvoidFlag = candidate.avoidCandidate // Reset to current value
            }
            Button(tempAvoidFlag ? "Mark as Avoid" : "Remove Avoid Flag") {
                candidate.updateAvoidFlag(to: tempAvoidFlag, reason: avoidFlagReason)
                avoidFlagReason = "" // Reset reason
            }
        } message: {
            Text(tempAvoidFlag
                 ? "Please provide a reason for marking this candidate as 'avoid'."
                 : "Please provide a reason for removing the avoid flag.")
        }
        .sheet(isPresented: $showingAvoidHistory) {
            NavigationView {
                List {
                    ForEach(candidate.avoidFlagHistory, id: \.date) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.date.formatted())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(entry.isEnabled ? "Marked as Avoid" : "Avoid Flag Removed")
                                .font(.headline)
                            
                            if let reason = entry.reason {
                                Text("Reason: \(reason)")
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Avoid Flag History")
                .navigationBarItems(trailing: Button("Done") {
                    showingAvoidHistory = false
                })
            }
        }
    }
    
    private func shareCandidate() {
        let info = candidate.exportData()
        
        let av = UIActivityViewController(
            activityItems: [info],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
    
    private func deleteCandidate() {
        modelContext.delete(candidate)
    }
}

#Preview {
    let candidate = Candidate(
        name: "John Doe",
        phoneNumber: "555-0123",
        email: "john@example.com",
        leadSource: .indeed,
        yearsOfExperience: 5,
        previousEmployers: [.dealership],
        technicalFocus: [.electrical],
        technicianLevel: .a
    )
    
    return CandidateDetailView(candidate: candidate)
}

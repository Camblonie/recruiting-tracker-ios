import SwiftUI
import SwiftData
import PhotosUI

/// View for editing an existing Company model.
struct CompanyEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var company: Company
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            Form {
                Section("Company Info") {
                    TextField("Name", text: $company.name)
                }

                Section("Logo") {
                    PhotosPicker(selection: $selectedImageItem, matching: .images) {
                        if let data = company.icon, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 100)
                                .overlay(Text("Select Logo"))
                        }
                    }
                    .onChange(of: selectedImageItem) { oldValue, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                company.icon = data
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Company")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CompanyEditorView(company: Company(name: "Example Co", icon: nil))
}

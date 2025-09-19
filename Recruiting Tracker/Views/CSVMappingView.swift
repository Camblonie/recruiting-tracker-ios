import SwiftUI

/// A simple mapping sheet that lets the user map CSV columns to Candidate fields.
/// Required fields: Phone AND either First Name or Name (legacy). Others are optional.
struct CSVMappingView: View {
    let headers: [String]
    let initialMapping: [CSVImporter.Field: Int]
    let initialOptions: CSVImporter.Options
    let onCancel: () -> Void
    let onConfirm: (_ mapping: [CSVImporter.Field: Int], _ options: CSVImporter.Options) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: [CSVImporter.Field: Int] = [:]
    @State private var delimiterChoice: DelimiterChoice = .auto
    @State private var ignoreQuotes: Bool = false

    enum DelimiterChoice: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case comma = "Comma"
        case semicolon = "Semicolon"
        case tab = "Tab"
        var id: String { rawValue }
        var character: Character? {
            switch self {
            case .auto: return nil
            case .comma: return ","
            case .semicolon: return ";"
            case .tab: return "\t"
            }
        }
    }

    private var canImport: Bool {
        // Allow import without phone mapping. Require either First Name OR Name.
        let firstNameOK = (selection[.firstName] ?? -1) >= 0
        let legacyNameOK = (selection[.name] ?? -1) >= 0
        return firstNameOK || legacyNameOK
    }

    private var headerChoices: [Int] { Array(headers.indices) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Required") {
                    // Require First Name OR legacy Name to be mapped (Import button enforces this)
                    mappingRow(field: .firstName)
                }
                Section("Optional") {
                    // Phone is recommended but not required for import
                    mappingRow(field: .phone)
                    mappingRow(field: .lastName)
                    // Legacy combined name fallback
                    mappingRow(field: .name)
                    mappingRow(field: .email)
                    mappingRow(field: .leadSource)
                    mappingRow(field: .company)
                    mappingRow(field: .yearsExperience)
                    mappingRow(field: .technicianLevel)
                    mappingRow(field: .hiringStatus)
                    mappingRow(field: .contacted)
                    mappingRow(field: .hotCandidate)
                    mappingRow(field: .needsFollowUp)
                    mappingRow(field: .needsInsurance)
                    mappingRow(field: .notes)
                    mappingRow(field: .dateEntered)
                }

                Section("Parsing") {
                    HStack {
                        Text("Delimiter")
                        Spacer()
                        Picker("", selection: $delimiterChoice) {
                            ForEach(DelimiterChoice.allCases) { choice in
                                Text(choice.rawValue).tag(choice)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Ignore Quotes (fallback)", isOn: $ignoreQuotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset to defaults") {
                        selection = CSVImporter.defaultMappingIndices(headers: headers)
                    }
                }
            }
            .navigationTitle("Map Columns")
            .navigationBarTitleDisplayMode(.inline)
            // Ensure strong contrast for the navigation title on this sheet
            .toolbarBackground(Color.slate, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let options = CSVImporter.Options(
                            delimiter: delimiterChoice.character,
                            ignoreQuotes: ignoreQuotes
                        )
                        onConfirm(selection, options)
                        dismiss()
                    }
                    .disabled(!canImport)
                }
            }
            .onAppear {
                selection = initialMapping
                // Seed parsing options from initialOptions
                ignoreQuotes = initialOptions.ignoreQuotes
                if let d = initialOptions.delimiter {
                    if d == "," { delimiterChoice = .comma }
                    else if d == ";" { delimiterChoice = .semicolon }
                    else if d == "\t" { delimiterChoice = .tab }
                    else { delimiterChoice = .auto }
                } else {
                    delimiterChoice = .auto
                }
            }
        }
    }

    @ViewBuilder
    private func mappingRow(field: CSVImporter.Field) -> some View {
        HStack {
            Text(field.rawValue)
            Spacer()
            Picker("", selection: Binding(get: { selection[field] ?? -1 }, set: { selection[field] = $0 })) {
                Text("Unmapped").tag(-1)
                ForEach(headerChoices, id: \.self) { idx in
                    Text(headers[idx]).tag(idx)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    CSVMappingView(
        headers: ["First Name", "Last Name", "Phone", "Email", "Lead Source"],
        initialMapping: [
            .firstName: 0,
            .lastName: 1,
            .phone: 2,
            .email: 3,
            .leadSource: 4
        ],
        initialOptions: .default,
        onCancel: {},
        onConfirm: { _, _ in }
    )
}

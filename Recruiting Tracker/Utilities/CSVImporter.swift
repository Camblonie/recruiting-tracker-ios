import Foundation
import SwiftData
import UniformTypeIdentifiers

/// CSV import utility for Recruiting Tracker.
/// - Parses CSV data exported by DatabaseExporter and maps rows to Candidate models.
/// - Skips duplicates by (name + phoneNumber) pair to avoid creating duplicates.
/// - Tries to parse enums case-insensitively; falls back to sensible defaults.
final class CSVImporter {
    /// Parsing options that can be supplied by the UI
    struct Options {
        /// Force a delimiter. If nil, auto-detect.
        var delimiter: Character?
        /// When true, ignore quotes while parsing (helpful for malformed CSV)
        var ignoreQuotes: Bool

        static let `default` = Options(delimiter: nil, ignoreQuotes: false)
    }
    /// Supported logical fields for mapping CSV columns to model properties
    enum Field: String, CaseIterable {
        case firstName = "First Name"
        case lastName = "Last Name"
        case name = "Name" // legacy single field fallback
        case phone = "Phone"
        case email = "Email"
        case leadSource = "Lead Source"
        case yearsExperience = "Years Experience"
        case technicianLevel = "Skill Level"
        case company = "Company"
        case hiringStatus = "Hiring Status"
        case contacted = "Contacted"
        case hotCandidate = "Hot Candidate"
        case needsFollowUp = "Needs Follow-up"
        case needsInsurance = "Needs Insurance"
        case notes = "Notes"
        case dateEntered = "Date Entered"
    }
    struct Result {
        let imported: Int
        let skipped: Int
        let errors: [String]
    }

    /// Import candidates from CSV data into the provided SwiftData ModelContext.
    /// - Parameters:
    ///   - csvData: UTF-8 encoded CSV data.
    ///   - context: SwiftData ModelContext to insert into.
    /// - Returns: Result summary with imported/skipped counts and any row-level errors.
    static func importCandidates(csvData: Data, into context: ModelContext) -> Result {
        guard let preview = preview(csvData: csvData) else {
            return Result(imported: 0, skipped: 0, errors: ["Invalid CSV encoding (expected UTF-8)"])
        }
        let headers = preview.headers
        _ = preview.rows // preview rows not used in this overload; mapping is computed then full import runs

        // Build default mapping from headers
        let mapping = defaultMappingIndices(headers: headers)
        return importCandidates(csvData: csvData, into: context, mapping: mapping)
    }

    /// Import with an explicit mapping of logical fields to column indices
    static func importCandidates(csvData: Data, into context: ModelContext, mapping: [Field: Int]) -> Result {
        return importCandidates(csvData: csvData, into: context, mapping: mapping, options: .default)
    }

    /// Import with explicit mapping and parsing options
    static func importCandidates(csvData: Data, into context: ModelContext, mapping: [Field: Int], options: Options) -> Result {
        guard let csvStringRaw = String(data: csvData, encoding: .utf8) else {
            return Result(imported: 0, skipped: 0, errors: ["Invalid CSV encoding (expected UTF-8)"])
        }
        let csvString = stripBOM(csvStringRaw)
        let delimiter = options.delimiter ?? detectDelimiter(csvString)
        var rows = parseCSV(csvString, delimiter: delimiter, respectQuotes: !options.ignoreQuotes)
        // Fallback: if only header and newlines exist, re-parse ignoring quotes (handles malformed quoting)
        if !options.ignoreQuotes && rows.count <= 1 && stringHasAnyNewline(csvString) {
            rows = parseCSV(csvString, delimiter: delimiter, respectQuotes: false)
        }
        guard !rows.isEmpty else { return Result(imported: 0, skipped: 0, errors: ["No rows detected in CSV file"]) }

        // Determine header row index (skip directive and blank lines)
        var headerIndex = 0
        while headerIndex < rows.count {
            let row = rows[headerIndex]
            let firstCell = row.first ?? ""
            let norm = normalize(firstCell)
            let rowAllEmpty = row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !rowAllEmpty && !norm.hasPrefix("sep=") { break }
            headerIndex += 1
        }
        guard headerIndex < rows.count else {
            return Result(imported: 0, skipped: 0, errors: ["No header row found in CSV after skipping directives/blank lines."])
        }
        let header = rows[headerIndex]
        let dataRows = rows.dropFirst(headerIndex + 1)
        if dataRows.isEmpty {
            var errs: [String] = ["No data rows found below the header. Check line endings or delimiter in your CSV."]
            errs.append("Diagnostics: delimiter=\(delimiter == "\t" ? "TAB" : String(delimiter))")
            errs.append("Header cols=\(header.count), total rows=\(rows.count)")
            errs.append("Headers=\(header.joined(separator: " | "))")
            return Result(imported: 0, skipped: 0, errors: errs)
        }

        // Prepare existing candidates set for deduplication
        let existing: [Candidate]
        do {
            existing = try context.fetch(FetchDescriptor<Candidate>())
        } catch {
            return Result(imported: 0, skipped: 0, errors: ["Failed to fetch existing candidates: \(error)"])
        }
        // Build a set of unique keys based on name + phone (phone stripped of whitespace)
        var existingKey = Set(existing.map {
            let normalizedPhone = String($0.phoneNumber.filter { !$0.isWhitespace }).lowercased()
            return $0.name.lowercased() + "|" + normalizedPhone
        })

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for (rowIndex, row) in dataRows.enumerated() {
            // Build safe accessor by logical field using provided mapping
            func val(_ field: Field) -> String? {
                guard let i = mapping[field], i >= 0, i < row.count else { return nil }
                let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return v.isEmpty ? nil : v
            }

            // Required minimal fields
            // Prefer First/Last Name, fallback to Name
            let composedName: String? = {
                let f = val(.firstName)
                let l = val(.lastName)
                if let f, let l { return f + " " + l }
                if let f { return f }
                if let l { return l }
                return val(.name)
            }()
            guard let name = composedName else {
                skipped += 1
                errors.append("Row \(rowIndex + 2): Missing required Name")
                continue
            }
            let phone = val(.phone) ?? ""

            let unique = name.lowercased() + "|" + phone.filter({ !$0.isWhitespace }).lowercased()
            if existingKey.contains(unique) {
                skipped += 1
                continue
            }

            // Optional fields
            let email = val(.email) ?? ""
            let leadSource = parseLeadSource(val(.leadSource))
            let years = Int(val(.yearsExperience) ?? "0") ?? 0
            let techLevel = parseTechnicianLevel(val(.technicianLevel))
            let hiringStatus = parseHiringStatus(val(.hiringStatus))
            let contacted = parseBool(val(.contacted))
            let isHot = parseBool(val(.hotCandidate))
            let needsFollowUp = parseBool(val(.needsFollowUp))
            let needsInsurance = parseBool(val(.needsInsurance))
            let enteredDate = parseDate(val(.dateEntered))
            let notes = val(.notes) ?? ""

            // Create Candidate with minimal required arrays set empty
            let candidate = Candidate(
                name: name,
                phoneNumber: phone,
                email: email,
                leadSource: leadSource,
                referralName: nil,
                yearsOfExperience: years,
                previousEmployers: [],
                technicalFocus: [],
                technicianLevel: techLevel,
                hiringStatus: hiringStatus,
                position: nil,
                dateEntered: enteredDate ?? Date()
            )
            candidate.isHotCandidate = isHot
            candidate.needsFollowUp = needsFollowUp
            candidate.needsHealthInsurance = needsInsurance
            if !notes.isEmpty { candidate.notes = notes }
            // Associate to Company (via default "General" Position) when provided
            if let companyName = val(.company)?.trimmingCharacters(in: .whitespacesAndNewlines), !companyName.isEmpty {
                do {
                    let companies = try context.fetch(FetchDescriptor<Company>())
                    let company: Company
                    if let existing = companies.first(where: { $0.name.caseInsensitiveCompare(companyName) == .orderedSame }) {
                        company = existing
                    } else {
                        let created = Company(name: companyName)
                        context.insert(created)
                        company = created
                    }
                    let defaultTitle = "General"
                    if let existingPos = (company.positions ?? []).first(where: { $0.title == defaultTitle }) {
                        candidate.position = existingPos
                    } else {
                        let createdPos = Position(title: defaultTitle, positionDescription: "Auto-created")
                        if company.positions == nil { company.positions = [] }
                        company.positions?.append(createdPos)
                        candidate.position = createdPos
                    }
                } catch {
                    // Swallow company association errors; candidate itself will still import
                }
            }
            // If 'Contacted' provided, nudge status when not explicitly set
            if contacted {
                if hiringStatus == .notContacted { candidate.hiringStatus = .visitForInterview }
            } else if let idx = mapping[.contacted], idx >= 0 { // only force if column included
                candidate.hiringStatus = .notContacted
            }

            context.insert(candidate)
            imported += 1
            existingKey.insert(unique)
        }

        // If nothing processed, add diagnostics for visibility
        if imported == 0 && skipped == 0 {
            var diag: [String] = []
            diag.append("Diagnostics: delimiter=\(delimiter == "\t" ? "TAB" : String(delimiter))")
            diag.append("Header cols=\(header.count), data rows=\(dataRows.count)")
            diag.append("Headers=\(header.joined(separator: " | "))")
            let phoneIdx = mapping[.phone] ?? -1
            let firstIdx = mapping[.firstName] ?? -1
            let lastIdx = mapping[.lastName] ?? -1
            let nameIdx = mapping[.name] ?? -1
            diag.append("Mapping: phone=\(phoneIdx), first=\(firstIdx), last=\(lastIdx), name=\(nameIdx)")
            errors.append(contentsOf: diag)
        }

        // Save once after batch for performance
        do {
            try context.save()
        } catch {
            errors.append("Save failed: \(error.localizedDescription)")
        }

        return Result(imported: imported, skipped: skipped, errors: errors)
    }

    // MARK: - Parsing helpers

    /// Return headers and all data rows for mapping/preview
    static func preview(csvData: Data) -> (headers: [String], rows: ArraySlice<[String]>)? {
        guard let csvStringRaw = String(data: csvData, encoding: .utf8) else { return nil }
        let csvString = stripBOM(csvStringRaw)
        let delim = detectDelimiter(csvString)
        var rows = parseCSV(csvString, delimiter: delim, respectQuotes: true)
        // Fallback for preview only: try ignoring quotes if we only got a header line
        if rows.count <= 1 && stringHasAnyNewline(csvString) {
            rows = parseCSV(csvString, delimiter: delim, respectQuotes: false)
        }
        guard !rows.isEmpty else { return nil }
        // Skip Excel delimiter directive lines like "sep=,"
        var headerIndex = 0
        while headerIndex < rows.count {
            let firstCell = rows[headerIndex].first ?? ""
            let norm = normalize(firstCell)
            if norm.hasPrefix("sep=") {
                headerIndex += 1
                continue
            }
            break
        }
        guard headerIndex < rows.count else { return nil }
        // Headers as-is; do not lowercase so we can show the user their original headings
        let headers = rows[headerIndex]
        let dataRows = rows.dropFirst(headerIndex + 1)
        return (headers, dataRows)
    }

    /// Best-effort default mapping from headers to fields (case-insensitive match)
    static func defaultMappingIndices(headers: [String]) -> [Field: Int] {
        var mapping: [Field: Int] = [:]
        let normalized = headers.map { normalize($0) }
        func find(_ candidates: [String]) -> Int? {
            for key in candidates.map(normalize) {
                if let idx = normalized.firstIndex(of: key) { return idx }
            }
            return nil
        }
        // Try common synonyms for robustness
        mapping[.firstName] = find([Field.firstName.rawValue, "first", "first name", "firstname", "first_name", "given name"]) ?? -1
        mapping[.lastName] = find([Field.lastName.rawValue, "last", "last name", "lastname", "last_name", "surname", "family name"]) ?? -1
        mapping[.name] = find([Field.name.rawValue, "full name", "fullname", "name (full)"]) ?? -1
        mapping[.phone] = find([
            Field.phone.rawValue,
            "phone number", "phone #", "phone#",
            "cell", "cell phone", "cellphone",
            "mobile", "mobile phone", "mobile number",
            "contact", "contact number",
            "telephone", "tel"
        ]) ?? -1
        mapping[.email] = find([Field.email.rawValue]) ?? -1
        mapping[.leadSource] = find([Field.leadSource.rawValue, "source"]) ?? -1
        mapping[.company] = find([Field.company.rawValue, "company name", "employer", "organization", "org"]) ?? -1
        mapping[.yearsExperience] = find([Field.yearsExperience.rawValue, "experience", "years exp", "yoe"]) ?? -1
        mapping[.technicianLevel] = find([
            Field.technicianLevel.rawValue,
            "level",
            "tech level",
            "technician level",
            "skill level",
            "skill"
        ]) ?? -1
        mapping[.hiringStatus] = find([Field.hiringStatus.rawValue, "status"]) ?? -1
        mapping[.contacted] = find([Field.contacted.rawValue, "was contacted", "has contacted"]) ?? -1
        mapping[.hotCandidate] = find([Field.hotCandidate.rawValue, "hot"]) ?? -1
        mapping[.needsFollowUp] = find([Field.needsFollowUp.rawValue, "follow up", "needs follow up"]) ?? -1
        mapping[.needsInsurance] = find([Field.needsInsurance.rawValue, "insurance"]) ?? -1
        mapping[.notes] = find([Field.notes.rawValue, "comments"]) ?? -1
        mapping[.dateEntered] = find([Field.dateEntered.rawValue, "created", "date"]) ?? -1
        return mapping
    }

    private static func normalize(_ s: String) -> String {
        stripBOM(s).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Strip Unicode Byte Order Mark if present (common in Excel-exported CSVs)
    private static func stripBOM(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    /// Heuristic to detect CSV delimiter (comma, semicolon, or tab) from the first line
    private static func detectDelimiter(_ text: String) -> Character {
        // Find the first non-empty, non-directive line (skip lines like "sep=,")
        var line = ""
        var inLine = false
        var i = 0
        let chars = Array(text)
        func isNewline(_ ch: Character) -> Bool { ch == "\n" || ch == "\r" || ch == "\u{2028}" || ch == "\u{2029}" || ch == "\u{0085}" || ch == "\u{000B}" || ch == "\u{000C}" }
        while i < chars.count {
            let ch = chars[i]
            if isNewline(ch) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let norm = normalize(trimmed)
                    if !norm.hasPrefix("sep=") { inLine = true; break }
                }
                line = ""
            } else {
                line.append(ch)
            }
            i += 1
        }
        if !inLine {
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let candidates: [Character] = [",", ";", "\t"]
        var best: (ch: Character, count: Int) = (",", 0)
        for ch in candidates {
            let c = line.reduce(0) { $1 == ch ? $0 + 1 : $0 }
            if c > best.count { best = (ch, c) }
        }
        return best.count > 0 ? best.ch : ","
    }

    /// Basic CSV parser that supports quoted fields and commas within quotes.
    /// Not RFC-perfect but sufficient for our export/import use cases.
    private static func parseCSV(_ text: String, delimiter: Character = ",", respectQuotes: Bool = true) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var atFieldStart = true
        var lastWasCR = false

        func endField() {
            current.append(field)
            field = ""
            atFieldStart = true
        }
        func endRow() {
            endField()
            rows.append(current)
            current = []
            atFieldStart = true
        }

        // Use indexed iteration so we can look ahead to handle escaped quotes ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let char = chars[i]
            if char == "\"" && respectQuotes { // quote
                if inQuotes {
                    // Escaped quote inside quoted field
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1 // consume the escape
                    } else {
                        // Tentative closing quote: only close if next is delimiter, newline, or end
                        let next = (i + 1 < chars.count) ? chars[i + 1] : "\0"
                        if next == delimiter || next == "\n" || next == "\r" || next == "\u{2028}" || next == "\u{2029}" || next == "\u{0085}" || next == "\0" {
                            inQuotes = false
                        } else {
                            // Treat as literal quote (malformed CSV but be lenient)
                            field.append("\"")
                        }
                    }
                } else {
                    if atFieldStart {
                        // Opening quote at start of field
                        inQuotes = true
                    } else {
                        // Literal quote inside unquoted field
                        field.append("\"")
                    }
                }
                lastWasCR = false
            } else if char == delimiter && !inQuotes {
                endField()
                lastWasCR = false
            } else if char == "\r" && !inQuotes {
                endRow()
                lastWasCR = true
            } else if char == "\n" && !inQuotes {
                if lastWasCR {
                    // Was CRLF; we've already ended the row on CR
                    lastWasCR = false
                } else {
                    endRow()
                }
            } else if (char == "\u{2028}" || char == "\u{2029}" || char == "\u{0085}" || char == "\u{000B}" || char == "\u{000C}") && !inQuotes {
                endRow()
                lastWasCR = false
            } else {
                field.append(char)
                atFieldStart = false
                lastWasCR = false
            }
            i += 1
        }
        // trailing field/row
        if !field.isEmpty || !current.isEmpty { endRow() }
        return rows
    }

    /// Return true if the string contains any recognized newline code points.
    private static func stringHasAnyNewline(_ s: String) -> Bool {
        s.contains("\n") || s.contains("\r") || s.contains("\u{2028}") || s.contains("\u{2029}") || s.contains("\u{0085}") || s.contains("\u{000B}") || s.contains("\u{000C}")
    }

    private static func parseBool(_ s: String?) -> Bool {
        guard let s else { return false }
        switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y": return true
        default: return false
        }
    }

    private static func parseLeadSource(_ s: String?) -> LeadSource {
        guard let s else { return .inPerson }
        let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for value in LeadSource.allCases {
            if value.rawValue.lowercased() == normalized { return value }
        }
        return .inPerson
    }

    private static func parseTechnicianLevel(_ s: String?) -> TechnicianLevel {
        guard let s else { return .unknown }
        let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for value in TechnicianLevel.allCases {
            if value.rawValue.lowercased() == normalized { return value }
        }
        return .unknown
    }

    private static func parseHiringStatus(_ s: String?) -> HiringStatus {
        guard let s else { return .notContacted }
        let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for value in HiringStatus.allCases {
            if value.rawValue.lowercased() == normalized { return value }
        }
        return .notContacted
    }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try ISO8601 first
        if let d = ISO8601DateFormatter().date(from: trimmed) { return d }
        // Try a couple of common formatted() styles
        let fmts = [
            "M/d/yy, h:mm a",
            "M/d/yyyy, h:mm a",
            "M/d/yy",
            "M/d/yyyy"
        ]
        for fmt in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }
}

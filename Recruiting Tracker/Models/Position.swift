import Foundation
import SwiftData

@Model
final class Position {
    // CloudKit requires defaults for non-optional attributes
    var title: String = ""
    var positionDescription: String = ""
    // CloudKit requires relationships to be optional
    var candidates: [Candidate]?
    var dateCreated: Date = Date()
    // Relationship to Company with explicit inverse; avoid default to prevent macro collisions
    @Relationship(inverse: \Company.positions) var company: Company?
    
    init(title: String, positionDescription: String) {
        self.title = title
        self.positionDescription = positionDescription
        self.dateCreated = Date()
    }
}

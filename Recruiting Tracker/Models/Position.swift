import Foundation
import SwiftData

@Model
final class Position {
    var title: String
    var positionDescription: String
    var candidates: [Candidate]
    var dateCreated: Date
    
    init(title: String, positionDescription: String) {
        self.title = title
        self.positionDescription = positionDescription
        self.candidates = []
        self.dateCreated = Date()
    }
}

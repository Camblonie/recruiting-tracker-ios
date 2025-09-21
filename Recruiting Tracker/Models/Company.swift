import Foundation
import SwiftData

@Model
final class Company {
    // CloudKit requires default values for non-optional attributes
    var name: String = ""
    var icon: Data?
    // CloudKit requires relationships to be optional. Use optional to-many and initialize on demand in code.
    var positions: [Position]?
    
    init(name: String, icon: Data? = nil) {
        self.name = name
        self.icon = icon
    }
}

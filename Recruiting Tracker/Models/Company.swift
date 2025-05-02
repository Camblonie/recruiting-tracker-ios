import Foundation
import SwiftData

@Model
final class Company {
    var name: String
    var icon: Data?
    var positions: [Position]
    
    init(name: String, icon: Data? = nil) {
        self.name = name
        self.icon = icon
        self.positions = []
    }
}

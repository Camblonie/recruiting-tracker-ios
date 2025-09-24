import Foundation

extension Notification.Name {
    /// Posted after a candidate is added and marked as needing follow-up
    static let didAddFollowUpCandidate = Notification.Name("didAddFollowUpCandidate")
    /// Posted when a letter is tapped on the A–Z index in the Recruiting Tracker tab
    /// userInfo: ["letter": String]
    static let didTapAlphabetIndex = Notification.Name("didTapAlphabetIndex")
}

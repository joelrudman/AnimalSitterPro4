import Foundation

struct MatchResult: Identifiable, Hashable {
    var id: String { company.id }
    var company: Company
    /// 0...100
    var score: Int
    /// Keywords that overlapped between the candidate and this company, best-weighted first.
    var matchedKeywords: [String]
    var reason: String
}

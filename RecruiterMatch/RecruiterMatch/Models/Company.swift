import Foundation

/// Static reference data describing a company's hiring profile. Shipped in the app bundle
/// as Resources/Companies.json — not user-editable, not stored in CloudKit.
struct Company: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var industry: String
    var subIndustries: [String]
    var size: String
    var hqLocation: String
    var description: String
    /// Skills / technologies / domains this company hires for. Highest-weight matching signal.
    var tags: [String]
    /// Job titles this company commonly hires for.
    var commonRoles: [String]
    /// Softer signals: culture, focus areas, mission keywords.
    var hiringKeywords: [String]

    static func loadBundled() -> [Company] {
        guard
            let url = Bundle.main.url(forResource: "Companies", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            assertionFailure("Companies.json missing from bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([Company].self, from: data)
        } catch {
            assertionFailure("Failed to decode Companies.json: \(error)")
            return []
        }
    }
}

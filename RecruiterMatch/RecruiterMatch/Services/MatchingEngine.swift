import Foundation

/// Scores a candidate against the bundled company dataset and returns the top N matches.
///
/// Approach: build a weighted keyword "bag of words" for the candidate (skills entered by the
/// recruiter count most, then title, then CV text, then free-form notes) and for each company
/// (tags count most, then common job titles, then softer hiring keywords). Score is a weighted
/// cosine similarity over those bags, plus a small bonus when the candidate's current title
/// closely matches one of the company's common roles. This runs entirely on-device — no
/// candidate data or CV content ever leaves CloudKit/the device to reach a third-party API.
enum MatchingEngine {

    private struct WeightedBag {
        var weights: [String: Double] = [:]

        mutating func add(_ tokens: [String], weight: Double) {
            for token in tokens {
                weights[token, default: 0] += weight
            }
        }

        var magnitude: Double {
            sqrt(weights.values.reduce(0) { $0 + $1 * $1 })
        }
    }

    static func topMatches(for candidate: Candidate, companies: [Company], limit: Int = 10) -> [MatchResult] {
        let candidateBag = buildCandidateBag(candidate)
        guard candidateBag.magnitude > 0 else { return [] }

        let results: [MatchResult] = companies.map { company in
            score(candidateBag: candidateBag, candidate: candidate, company: company)
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Bag construction

    private static func buildCandidateBag(_ candidate: Candidate) -> WeightedBag {
        var bag = WeightedBag()

        let skillTokens = candidate.skills.map { Keywords.normalizePhrase($0) }.filter { !$0.isEmpty }
        bag.add(skillTokens, weight: 4.0)

        bag.add(Keywords.tokenize(candidate.currentTitle), weight: 2.5)

        if let cvText = candidate.cvText, !cvText.isEmpty {
            // CV text is long and noisy; cap its influence relative to explicit skills/title.
            let cvTokens = Keywords.tokenize(cvText)
            let capped = Array(topFrequent(cvTokens, cap: 60))
            bag.add(capped, weight: 1.0)
        }

        bag.add(Keywords.tokenize(candidate.summary), weight: 1.5)

        return bag
    }

    private static func buildCompanyBag(_ company: Company) -> WeightedBag {
        var bag = WeightedBag()
        bag.add(company.tags.map(Keywords.normalizePhrase), weight: 4.0)
        for role in company.commonRoles {
            bag.add(Keywords.tokenize(role), weight: 2.5)
        }
        bag.add(company.hiringKeywords.map(Keywords.normalizePhrase), weight: 1.5)
        bag.add(Keywords.tokenize(company.industry), weight: 2.0)
        for sub in company.subIndustries {
            bag.add(Keywords.tokenize(sub), weight: 1.5)
        }
        return bag
    }

    /// Keeps only the most frequent tokens so a long CV doesn't drown out a short one purely
    /// on volume; returns tokens in descending frequency order.
    private static func topFrequent(_ tokens: [String], cap: Int) -> [String] {
        var counts: [String: Int] = [:]
        for token in tokens { counts[token, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(cap).map { $0.key }
    }

    // MARK: - Scoring

    private static func score(candidateBag: WeightedBag, candidate: Candidate, company: Company) -> MatchResult {
        let companyBag = buildCompanyBag(company)

        var dot = 0.0
        var matched: [(token: String, weight: Double)] = []
        for (token, cWeight) in candidateBag.weights {
            if let compWeight = companyBag.weights[token] {
                dot += cWeight * compWeight
                matched.append((token, cWeight * compWeight))
            }
        }

        let denom = candidateBag.magnitude * companyBag.magnitude
        var cosine = denom > 0 ? dot / denom : 0

        // Title/role affinity bonus: does the candidate's current title share meaningful
        // tokens with any role this company commonly hires for?
        let titleTokens = Set(Keywords.tokenize(candidate.currentTitle))
        var roleBonus = 0.0
        if !titleTokens.isEmpty {
            for role in company.commonRoles {
                let roleTokens = Set(Keywords.tokenize(role))
                let overlap = titleTokens.intersection(roleTokens)
                if !overlap.isEmpty {
                    let fraction = Double(overlap.count) / Double(titleTokens.count)
                    roleBonus = max(roleBonus, fraction * 0.15)
                }
            }
        }

        cosine = min(1.0, cosine + roleBonus)
        let score = Int((cosine * 100).rounded())

        let topKeywords = matched
            .sorted { $0.weight > $1.weight }
            .prefix(6)
            .map { $0.token }

        let reason = buildReason(candidate: candidate, company: company, matchedKeywords: Array(topKeywords), roleBonus: roleBonus)

        return MatchResult(company: company, score: score, matchedKeywords: Array(topKeywords), reason: reason)
    }

    private static func buildReason(candidate: Candidate, company: Company, matchedKeywords: [String], roleBonus: Double) -> String {
        guard !matchedKeywords.isEmpty else {
            return "Some overlap with \(company.industry) roles, but no strong skill match found."
        }
        let list = matchedKeywords.prefix(4).joined(separator: ", ")
        var reason = "Overlaps on \(list)."
        if roleBonus > 0 {
            reason += " Current title aligns with roles \(company.name) commonly hires for."
        }
        return reason
    }
}

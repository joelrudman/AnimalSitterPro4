import Foundation

/// Tokenization, stopword filtering, and a small synonym table shared by CV parsing and matching.
enum Keywords {

    static let stopwords: Set<String> = [
        "the", "and", "a", "an", "of", "to", "in", "on", "for", "with", "at", "by", "from",
        "as", "is", "are", "was", "were", "be", "been", "being", "this", "that", "these",
        "those", "it", "its", "we", "our", "you", "your", "i", "he", "she", "they", "them",
        "their", "or", "but", "if", "then", "than", "so", "such", "not", "no", "yes",
        "will", "would", "can", "could", "should", "may", "might", "must", "shall",
        "have", "has", "had", "do", "does", "did", "using", "used", "use", "into",
        "over", "under", "about", "up", "down", "out", "off", "again", "further",
        "years", "year", "experience", "work", "worked", "working", "responsible",
        "including", "include", "included", "etc", "also", "within", "across",
        "team", "teams", "role", "roles", "company", "companies", "job", "jobs",
        "skills", "skill", "strong", "proven", "excellent", "ability", "abilities",
        "knowledge", "understanding", "including", "various", "multiple", "new",
        "phone", "email", "address", "resume", "cv", "curriculum", "vitae",
        "references", "available", "request", "http", "https", "www"
    ]

    /// Normalizes common abbreviations/variants to a canonical keyword so e.g.
    /// "JS" on a CV lines up with "javascript" in a company's tag list.
    static let synonyms: [String: String] = [
        "js": "javascript",
        "ts": "typescript",
        "reactjs": "react",
        "react.js": "react",
        "node": "nodejs",
        "node.js": "nodejs",
        "ml": "machine learning",
        "ai": "artificial intelligence",
        "nlp": "natural language processing",
        "swiftui": "swift",
        "objective-c": "objectivec",
        "objective c": "objectivec",
        "aws": "amazon web services",
        "gcp": "google cloud platform",
        "k8s": "kubernetes",
        "cs": "computer science",
        "ux": "user experience",
        "ui": "user interface",
        "qa": "quality assurance",
        "pm": "product management",
        "hr": "human resources",
        "biz dev": "business development",
        "bd": "business development",
        "cx": "customer experience",
        "devops": "developer operations",
        "sql server": "sql",
        "postgres": "postgresql",
        "py": "python",
        "fe": "frontend",
        "be": "backend",
        "fs": "fullstack",
        "full stack": "fullstack",
        "full-stack": "fullstack"
    ]

    /// Splits free text into lowercase, punctuation-stripped tokens with stopwords removed
    /// and synonyms normalized. Multi-word phrases are also emitted as a single joined token
    /// so e.g. "machine learning" survives as one keyword rather than two generic words.
    static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -./+#"))
        let cleaned = String(lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " })

        let rawWords = cleaned
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map(String.init)
            .filter { !$0.isEmpty }

        var tokens: [String] = []
        for word in rawWords {
            let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "-./"))
            guard trimmed.count > 1, !stopwords.contains(trimmed) else { continue }
            let normalized = synonyms[trimmed] ?? trimmed
            tokens.append(normalized)
        }
        return tokens
    }

    /// Normalizes a short phrase (e.g. a manually-entered skill or a company tag) into a
    /// single canonical keyword, collapsing internal whitespace and applying synonyms.
    static func normalizePhrase(_ phrase: String) -> String {
        let lowered = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return synonyms[lowered] ?? lowered
    }
}

import SwiftUI

struct MatchResultsView: View {
    @EnvironmentObject private var store: CandidateStore
    let candidate: Candidate

    private var matches: [MatchResult] {
        store.topMatches(for: candidate)
    }

    var body: some View {
        Group {
            if matches.isEmpty {
                ContentUnavailableView(
                    "Not Enough Signal Yet",
                    systemImage: "questionmark.circle",
                    description: Text("Add a few skills, a title, or a CV to \(candidate.fullName.isEmpty ? "this candidate" : candidate.fullName) so matches can be computed.")
                )
            } else {
                List {
                    Section {
                        Text("Ranked by overlap between \(candidate.fullName.isEmpty ? "the candidate's" : candidate.fullName + "'s") skills, title, and CV against each company's hiring profile.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                        NavigationLink {
                            CompanyDetailView(match: match, rank: index + 1)
                        } label: {
                            MatchRow(rank: index + 1, match: match)
                        }
                    }
                }
            }
        }
        .navigationTitle("Top Companies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MatchRow: View {
    let rank: Int
    let match: MatchResult

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            ScoreBadge(score: match.score)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.company.name)
                    .font(.headline)
                Text(match.company.industry)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !match.matchedKeywords.isEmpty {
                    Text(match.matchedKeywords.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

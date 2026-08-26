import SwiftUI

struct CompanyDetailView: View {
    let match: MatchResult
    let rank: Int

    var body: some View {
        List {
            Section {
                HStack {
                    ScoreBadge(score: match.score)
                    VStack(alignment: .leading) {
                        Text("Rank #\(rank) match")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(match.score)% overlap")
                            .font(.headline)
                    }
                }
                Text(match.reason)
                    .font(.subheadline)
            }

            Section("About") {
                LabeledContent("Industry", value: match.company.industry)
                if !match.company.subIndustries.isEmpty {
                    LabeledContent("Focus", value: match.company.subIndustries.joined(separator: ", "))
                }
                LabeledContent("Size", value: match.company.size)
                LabeledContent("HQ", value: match.company.hqLocation)
                Text(match.company.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            if !match.matchedKeywords.isEmpty {
                Section("Why This Match") {
                    WrapLayout(spacing: 8) {
                        ForEach(match.matchedKeywords, id: \.self) { keyword in
                            SkillChipView(text: keyword)
                        }
                    }
                }
            }

            if !match.company.commonRoles.isEmpty {
                Section("Roles They Commonly Hire") {
                    ForEach(match.company.commonRoles, id: \.self) { role in
                        Text(role.capitalized)
                    }
                }
            }
        }
        .navigationTitle(match.company.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

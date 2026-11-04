import SwiftUI
import SwiftData

/// Every bartender you've recorded, grouped by pub. Nearest pubs first when we know
/// where you are.
struct DirectoryView: View {
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bartender.name) private var bartenders: [Bartender]

    @State private var searchText = ""
    @State private var favouritesOnly = false

    private var groups: [PubGroup] {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = bartenders.filter { bartender in
            (!favouritesOnly || bartender.isFavourite)
                && (term.isEmpty
                    || bartender.name.localizedCaseInsensitiveContains(term)
                    || bartender.pubName.localizedCaseInsensitiveContains(term)
                    || bartender.notes.localizedCaseInsensitiveContains(term))
        }
        let groups = PubGroup.group(filtered)
        if let here = pubModel.location {
            return groups.sorted { $0.pub.location.distance(from: here) < $1.pub.location.distance(from: here) }
        }
        return groups.sorted { $0.pub.name.localizedCaseInsensitiveCompare($1.pub.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.bartenders) { bartender in
                            NavigationLink(value: bartender) {
                                BartenderRow(bartender: bartender, showsPub: false)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { group.bartenders[$0] }.forEach { modelContext.delete($0) }
                        }
                    } header: {
                        PubHeader(pub: group.pub, distance: group.pub.distance(from: pubModel.location))
                    }
                }
            }
            .overlay {
                if bartenders.isEmpty {
                    ContentUnavailableView(
                        "Your directory is empty",
                        systemImage: "person.2",
                        description: Text("Bartenders you add on the Here tab show up here, grouped by pub.")
                    )
                } else if groups.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Directory")
            .navigationDestination(for: Bartender.self) { BartenderDetailView(bartender: $0) }
            .searchable(text: $searchText, prompt: "Bartenders, pubs, notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $favouritesOnly) {
                        Label("Favourites only", systemImage: favouritesOnly ? "star.fill" : "star")
                    }
                    .toggleStyle(.button)
                }
            }
            .bannerAdInset()
        }
    }
}

private struct PubHeader: View {
    let pub: Pub
    let distance: Double?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(pub.name, systemImage: "mug.fill")
            Spacer()
            if let distance {
                Text(distance.formattedDistance)
                    .font(.caption)
                    .textCase(nil)
            }
        }
    }
}

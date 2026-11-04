import SwiftUI

/// Choose the pub manually: nearby list, search by name, or type one in.
struct PubPickerView: View {
    @Environment(CurrentPubModel.self) private var pubModel
    @Environment(\.dismiss) private var dismiss

    var onSelect: (Pub) -> Void

    @State private var query = ""
    @State private var results: [Pub] = []
    @State private var isSearching = false
    @State private var customName = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("Nearby") {
                        if pubModel.nearbyPubs.isEmpty {
                            Text(pubModel.state == .locating ? "Searching…" : "Nothing found nearby — try searching.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(pubModel.nearbyPubs) { pubRow($0) }
                    }
                } else {
                    Section("Results") {
                        if isSearching {
                            ProgressView()
                        } else if results.isEmpty {
                            Text("No matches for “\(query)”").foregroundStyle(.secondary)
                        }
                        ForEach(results) { pubRow($0) }
                    }
                }

                Section {
                    TextField("Pub name", text: $customName)
                        .textInputAutocapitalization(.words)
                    Button("Use this name at my location") {
                        if let pub = pubModel.customPub(named: customName) { choose(pub) }
                    }
                    .disabled(pubModel.customPub(named: customName) == nil)
                } header: {
                    Text("Not listed?")
                } footer: {
                    if pubModel.location == nil {
                        Text("Needs your location so the pub can be found again next time you're there.")
                    }
                }
            }
            .navigationTitle("Choose pub")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search pubs by name")
            .task(id: query) { await search() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pubRow(_ pub: Pub) -> some View {
        Button { choose(pub) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pub.name).foregroundStyle(.primary)
                    if !pub.address.isEmpty {
                        Text(pub.address).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let distance = pub.distance(from: pubModel.location) {
                    Text(distance.formattedDistance).font(.caption).foregroundStyle(.secondary)
                }
                if let current = pubModel.currentPub, current.isSamePlace(as: pub) {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }

    private func choose(_ pub: Pub) {
        onSelect(pub)
        dismiss()
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(350)) // debounce typing
        guard !Task.isCancelled else { return }
        results = await PubFinder.search(text, near: pubModel.location)
        isSearching = false
    }
}
